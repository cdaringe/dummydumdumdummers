-module(thingfactory_erlang_cli).
-export([read_line_sync/0, write_file/3]).

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
