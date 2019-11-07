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
      (-1, Info.please_report())
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
          [ OptionSpec.string(
              "package", "only show versions for given package", None, "")
          ])? // TODO: show [<options>] in help message
        CommandSpec.leaf(
          "update",
          "Install the latest release of the given toolchain version/channel",
          [ OptionSpec.string(
              "libc", "Specify libc (gnu or musl)", None, "gnu")
          ],
          [ ArgSpec.string("package")
            ArgSpec.string("version/channel")
          ])?
      ])?
      .> add_help("help", "Print this message and exit")?
