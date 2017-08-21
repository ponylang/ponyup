use "files"
use "process"

// TODO shellcheck
// TODO multi threaded option?

actor Main
  new create(env: Env) =>
    let auth =
      try env.root as AmbientAuth
      else
        env.err.print("invalid authority")
        return
      end
    let dockerfile =
      try FilePath(auth, "Dockerfile")?
      else
        env.err.print("unable to create Dockerfile")
        return
      end
    TestRunner(env, auth, dockerfile)

actor TestRunner
  let _env: Env
  let _auth: AmbientAuth
  var _dockerfile: FilePath
  let _builds: Array[(String, String)] =
    recover
      [ // ("ubuntu:trusty", "ubuntu-trusty-source.sh")
        ("ubuntu:trusty", "ubuntu-trusty.sh")
        // ("ubuntu:xenial", "ubuntu-xenial-source.sh")
        ("ubuntu:xenial", "ubuntu-xenial.sh")
      ]
    end

  new create(env: Env, auth: AmbientAuth, dockerfile: FilePath) =>
    _env = env
    _auth = auth
    _dockerfile = consume dockerfile
    build()
  
  fun ref create_dockerfile() ? =>
    (let base_image: String, let script: String) = _builds.shift()?
    let script_path = "install-scripts/" + script
    let text =
      recover val
        String
          .> append("FROM ") .> append(base_image) .> append("\n\n")
          .> append("COPY ") .> append(script_path) .> append(" . \n")
          .> append("RUN sh ") .> append(script) .> append("\n")
          .> append(
            """
            
            RUN git clone https://github.com/ponylang/ponyc
            WORKDIR ponyc
            RUN ponyc -d --verify packages/stdlib
            RUN ./stdlib
            """)
      end
    
    match CreateFile(_dockerfile)
    | let file: File =>
      file
        .> write(text)
        .> flush()
        .> dispose()
    else error
    end

  be build_complete(success: Bool) =>
    if success then build()
    else
      dispose()
      _env.err.print("build failure")
    end

  fun ref build() =>
    try
      create_dockerfile()?
    else
      dispose()
      _env.out.print("\n\nDone.\n")
      return
    end

    let notify = DockerfileBuildNotify(_env, this)
    let path =
      try FilePath(_auth, "/usr/bin/docker")?
      else
        _env.out.print("try running as root")
        return
      end
    let args =
      recover val
        Array[String]
          .> push("docker")
          .> push("build")
          .> push(".")
          .> push("-f")
          .> push("Dockerfile")
      end
    let vars = recover val Array[String] end
    ProcessMonitor(_auth, consume notify, path, args, vars)
  
  fun ref dispose() =>
    _dockerfile.remove()

class DockerfileBuildNotify is ProcessNotify
  let _env: Env
  let _runner: TestRunner

  new iso create(env: Env, runner: TestRunner) =>
    _env = consume env
    _runner = runner

  fun ref stdout(process: ProcessMonitor ref, data: Array[U8] iso) =>
    _env.out.write(consume data)

  fun ref stderr(process: ProcessMonitor ref, data: Array[U8] iso) =>
    _env.err.write(consume data)
  
  fun ref failed(process: ProcessMonitor ref, err: ProcessError) =>
    _env.err.print("process error") // TODO
  
  fun ref dispose(process: ProcessMonitor ref, exit_code: I32) =>
    _env.out.print("child process exit: " + exit_code.string())
    _runner.build_complete(exit_code == 0)
