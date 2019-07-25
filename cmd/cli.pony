use "cli"

primitive CLI
  fun _project_repo_link(): String => "https://github.com/theodus/ponyup"
  fun _default_prefix(): String => "~/.pony/ponyup"

  fun parse(args: Array[String] box, envs: (Array[String] box | None))
    : (U8, (Command | String))
  =>
    try
      match CommandParser(_spec()?).parse(args, envs)
      | let c: Command => (0, c)
      | let h: CommandHelp => (0, h.help_string())
      | let e: SyntaxError => (1, e.string())
      end
    else
      (-1, "Internal error. Please open an issue at " + _project_repo_link())
    end

  fun _spec(): CommandSpec ? =>
    CommandSpec.parent(
      "ponyup",
      "The Pony toolchain multiplexer",
      [ OptionSpec.bool(
          "boring", "Do not use colorful output", 'b', false)
        OptionSpec.string(
          "prefix", "Specify toolchain install prefix", 'p', _default_prefix())
        OptionSpec.bool(
          "verbose", "Show extra output", 'v', false)
        OptionSpec.bool(
          "version", "Display the ponyup version and exit", 'V', false)
      ],
      [ CommandSpec.leaf(
          "show",
          "Show the active toolchain version",
          [ OptionSpec.bool("all", "List all availible toolchains")
            OptionSpec.bool("installed", "List all installed toolchains")
          ], // TODO: show [<options>] in help message
          [])?
        CommandSpec.leaf(
          "update",
          "Install the latest release of the given toolchain version/channel",
          [],
          [ ArgSpec.string("version/channel")
          ])?
      ])?
      .> add_help("help", "Print this message and exit")?
