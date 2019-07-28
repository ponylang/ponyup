primitive Info
  fun version(): String =>
    "0.0.1"

  fun project_repo_link(): String =>
    "https://github.com/theodus/ponyup"

  fun please_report(): String =>
    "Internal error encountered. Please open an issue at " + project_repo_link()

actor Main
  new create(env: Env) =>
    if not Platform.linux() then
      env.exitcode(1)
      env.out.print("error: Unsupported platform")
      return
    end

    let auth =
      try
        env.root as AmbientAuth
      else
        env.exitcode(1)
        env.out.print("error: environment does not have ambient authority")
        return
      end

    Ponyup(env.out, auth, env)
