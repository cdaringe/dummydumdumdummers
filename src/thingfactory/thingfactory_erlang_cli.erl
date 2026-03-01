-module(thingfactory_erlang_cli).
-export([load_pipeline/2, load_pipeline_from_file/2, read_line_sync/0, write_file/3, get_cwd/0]).

load_pipeline(ModuleName, FunctionName) ->
    case to_atom(ModuleName) of
        {ok, ModuleAtom} ->
            case to_atom(FunctionName) of
                {ok, FunctionAtom} ->
                    load_pipeline_atoms(ModuleAtom, FunctionAtom, ModuleName, FunctionName, no_build);
                {error, Msg} ->
                    {error, Msg}
            end;
        {error, Msg} ->
            {error, Msg}
    end.

load_pipeline_from_file(FilePath, FunctionName) ->
    case filelib:is_file(binary_to_list(FilePath)) of
        false ->
            {error,
                list_to_binary(
                    io_lib:format(
                        "Pipeline source file not found: ~ts",
                        [FilePath]
                    )
                )};
        true ->
            case module_name_from_file(FilePath) of
                {error, Msg} ->
                    {error, Msg};
                {ok, ModuleName} ->
                    case to_atom(ModuleName) of
                        {error, Msg} ->
                            {error, Msg};
                        {ok, ModuleAtom} ->
                            case to_atom(FunctionName) of
                                {error, Msg} ->
                                    {error, Msg};
                                {ok, FunctionAtom} ->
                                    case find_project_root(filename:dirname(binary_to_list(filename:absname(FilePath)))) of
                                        {ok, ProjectRoot} ->
                                            load_pipeline_atoms(
                                                ModuleAtom,
                                                FunctionAtom,
                                                ModuleName,
                                                FunctionName,
                                                ProjectRoot
                                            );
                                        {error, Msg} ->
                                            {error, Msg}
                                    end
                            end
                    end
            end
    end.

load_pipeline_atoms(ModuleAtom, FunctionAtom, ModuleName, FunctionName, BuildRoot) ->
    case code:ensure_loaded(ModuleAtom) of
        {module, _} ->
            execute_pipeline(ModuleAtom, FunctionAtom, ModuleName, FunctionName);
        {error, Reason} ->
            maybe_build_and_retry(
                BuildRoot,
                ModuleAtom,
                FunctionAtom,
                ModuleName,
                FunctionName,
                Reason
            )
    end.

execute_pipeline(ModuleAtom, FunctionAtom, ModuleName, FunctionName) ->
    case erlang:function_exported(ModuleAtom, FunctionAtom, 0) of
        true ->
            try
                {ok, apply(ModuleAtom, FunctionAtom, [])}
            catch
                Class:Reason ->
                    {error,
                        list_to_binary(
                            io_lib:format(
                                "Failed to load pipeline ~ts:~ts (~p:~p)",
                                [ModuleName, FunctionName, Class, Reason]
                            )
                        )}
            end;
        false ->
            {error,
                list_to_binary(
                    io_lib:format(
                        "Pipeline function not found: ~ts:~ts",
                        [ModuleName, FunctionName]
                    )
                )}
    end.

maybe_build_and_retry(no_build, _ModuleAtom, _FunctionAtom, ModuleName, _FunctionName, Reason) ->
    {error,
        list_to_binary(
            io_lib:format(
                "Pipeline module not loadable: ~ts (~p)",
                [ModuleName, Reason]
            )
        )};
maybe_build_and_retry(BuildRoot, ModuleAtom, FunctionAtom, ModuleName, FunctionName, _Reason) ->
    case run_gleam_build(BuildRoot) of
        ok ->
            code:purge(ModuleAtom),
            code:delete(ModuleAtom),
            case code:ensure_loaded(ModuleAtom) of
                {module, _} ->
                    execute_pipeline(ModuleAtom, FunctionAtom, ModuleName, FunctionName);
                {error, RetryReason} ->
                    {error,
                        list_to_binary(
                            io_lib:format(
                                "Pipeline module not loadable after build: ~ts (~p)",
                                [ModuleName, RetryReason]
                            )
                        )}
            end;
        {error, BuildOutput} ->
            {error,
                list_to_binary(
                    io_lib:format(
                        "Failed to build pipeline file ~ts (~ts)",
                        [ModuleName, BuildOutput]
                    )
                )}
    end.

module_name_from_file(FilePath) ->
    Normalized = binary:replace(FilePath, <<"\\">>, <<"/">>, [global]),
    case re:run(Normalized, <<"(?:^|/)(?:src|test)/(.+)\\.gleam$">>, [{capture, [1], binary}]) of
        {match, [ModulePath]} ->
            {ok, binary:replace(ModulePath, <<"/">>, <<"@">>, [global])};
        nomatch ->
            {error,
                <<"Unable to derive module name from file path. Expected a .gleam file under src/ or test/.">>}
    end.

find_project_root(Dir) ->
    case filelib:is_file(filename:join(Dir, "gleam.toml")) of
        true ->
            {ok, Dir};
        false ->
            Parent = filename:dirname(Dir),
            case Parent =:= Dir of
                true ->
                    {error,
                        <<"Could not find gleam.toml while walking upward from pipeline file path.">>};
                false ->
                    find_project_root(Parent)
            end
    end.

run_gleam_build(ProjectRoot) ->
    Cmd = "cd " ++ shell_quote(ProjectRoot) ++ " && gleam build --target erlang --warnings-as-errors",
    case run_command(Cmd) of
        {ok, _Output} -> ok;
        {error, Output} -> {error, Output}
    end.

run_command(Cmd) ->
    Port = open_port({spawn, Cmd}, [binary, exit_status, hide, stderr_to_stdout, use_stdio]),
    collect_port_output(Port, <<>>).

collect_port_output(Port, Acc) ->
    receive
        {Port, {data, Data}} ->
            collect_port_output(Port, <<Acc/binary, Data/binary>>);
        {Port, {exit_status, 0}} ->
            {ok, Acc};
        {Port, {exit_status, _Code}} ->
            {error, Acc}
    end.

shell_quote(Path) ->
    Escaped = lists:flatten(string:replace(Path, "'", "'\\''", all)),
    "'" ++ Escaped ++ "'".

to_atom(Name) ->
    try
        {ok, binary_to_atom(Name, utf8)}
    catch
        error:badarg ->
            {error,
                list_to_binary(
                    io_lib:format(
                        "Invalid module/function name: ~ts",
                        [Name]
                    )
                )}
    end.

read_line_sync() ->
    case io:get_line("") of
        eof -> {error, nil};
        {error, _} -> {error, nil};
        Line ->
            Trimmed = string:trim(Line, trailing, "\n"),
            {ok, list_to_binary(Trimmed)}
    end.

write_file(Dir, Filename, Content) ->
    DirStr = binary_to_list(Dir),
    FilenameStr = binary_to_list(Filename),
    ok = filelib:ensure_dir(DirStr ++ "/"),
    Path = filename:join(DirStr, FilenameStr),
    case file:write_file(Path, Content) of
        ok -> {ok, list_to_binary(Path)};
        {error, Reason} ->
            {error, list_to_binary(io_lib:format("~p", [Reason]))}
    end.

get_cwd() ->
    case file:get_cwd() of
        {ok, Dir} -> {ok, list_to_binary(Dir)};
        {error, Reason} ->
            {error, list_to_binary(io_lib:format("~p", [Reason]))}
    end.
