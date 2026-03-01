-module(thingfactory_erlang_cli).
-export([load_pipeline/2, read_line_sync/0, write_file/3]).

load_pipeline(ModuleName, FunctionName) ->
    case to_atom(ModuleName) of
        {ok, ModuleAtom} ->
            case to_atom(FunctionName) of
                {ok, FunctionAtom} ->
                    case code:ensure_loaded(ModuleAtom) of
                        {module, _} ->
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
                            end;
                        {error, Reason} ->
                            {error,
                                list_to_binary(
                                    io_lib:format(
                                        "Pipeline module not loadable: ~ts (~p)",
                                        [ModuleName, Reason]
                                    )
                                )}
                    end;
                {error, Msg} ->
                    {error, Msg}
            end;
        {error, Msg} ->
            {error, Msg}
    end.

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
