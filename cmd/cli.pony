use "cli"

primitive CLI
  fun parse(
    args: Array[String] box,
    envs: (Array[String] box | None),
    default_prefix: String)
    : (Command | (U8, String))
  =>
    try
      match CommandParser(_spec(default_prefix)?).parse(args, envs)
      | let c: Command => c
      | let h: CommandHelp => (0, h.help_string())
      | let e: SyntaxError => (1, e.string())
      end
    else
      (-1, "unable to parse command")
    end

  fun help(default_prefix: String): String =>
    try Help.general(_spec(default_prefix)?).help_string() else "" end

  fun _spec(default_prefix: String): CommandSpec ? =>
    CommandSpec.parent(
      "ponyup",
      "The Pony toolchain multiplexer",
      [ OptionSpec.bool(
          "boring", "Do not use colorful output", 'b', false)
        OptionSpec.string(
          "prefix", "Specify toolchain install prefix", 'p', default_prefix)
        OptionSpec.bool(
          "verbose", "Show extra output", 'v', false)
      ],
      [ CommandSpec.leaf(
          "version",
          "Display the ponyup version and exit")?
        CommandSpec.leaf(
          "show",
          "Show installed package versions",
          [ OptionSpec.bool(
              "local", "only show installed package versions", None, false)
          ],
          [ ArgSpec.string("package" where default' = "")
          ])? // TODO: show [<options>] in help message
        CommandSpec.leaf(
          "find",
          "Find available package versions",
          [],
          [ ArgSpec.string("package")
            ArgSpec.string("channel" where default' = "")
          ])?
        CommandSpec.leaf(
          "update",
          "Install or update a package",
          [ OptionSpec.string(
              "platform",
              "Specify platform (such as x86_64-linux-ubuntu24.04)",
              None,
              "")
          ],
          [ ArgSpec.string("package")
            ArgSpec.string("version/channel")
          ])?
        CommandSpec.leaf(
          "select",
          "Select the default version for a package",
          [ OptionSpec.string(
              "platform",
              "Specify platform (such as x86_64-linux-ubuntu24.04)",
              None,
              "")
          ],
          [ ArgSpec.string("package")
            ArgSpec.string("version")
          ])?
        CommandSpec.leaf(
          "default",
          "Set the default platform (such as x86_64-linux-ubuntu24.04)",
          [],
          [ ArgSpec.string("platform")
          ])?
      ])?
      .> add_help("help", "Print this message and exit")?
