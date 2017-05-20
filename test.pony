use "files"
use "ponytest"

// TODO shellcheck
// TODO single threaded?

actor Main is TestList
  new create(env: Env) => PonyTest(env, this)

  fun tag tests(test: PonyTest) =>
    test(TestInstall("ubuntu-14", "Ubuntu:14.04"))

class iso TestInstall is UnitTest
  let script_name: String
  let script_path: String
  let base_image: String

  new iso create(script': String, base_image': String) =>
    (script_name, base_image) = (script', base_image')
    script_path = "./install-scripts/" + script' + ".sh"

  fun name(): String => base_image

  fun apply(h: TestHelper) ? =>
    let auth = h.env.root as AmbientAuth
    let dockerfile = "Dockerfile-" + script_name
    let file = 
      match CreateFile(FilePath(auth, dockerfile))
      | let f: File => f
      else
        h.log("file error") // TODO better message
        error
      end
    file
      .> write(_dockerfile())
      .> flush()
      .> dispose()

  fun _dockerfile(): String =>
    recover String
      .> append("FROM ") .> append(base_image) .> append("\n\n")
      .> append("COPY ") .> append(script_path) .> append(" . \n")
      .> append("RUN ./") .> append(script_name) .> append("\n")
      .> append(
        """
        RUN ponyc /usr/local/ponyc/examples/helloworld
        RUN ./helloworld
        """)
    end
