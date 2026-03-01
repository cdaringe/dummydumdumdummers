-module(command_runner_erlang).
-export([run_command/2, run_command_in_dir/3]).

% Run a shell command with arguments.
% Returns {ok, {ExitCode, Stdout, Stderr}} or {error, Message}.
run_command(Program, Args) ->
    run_command_in_dir(Program, Args, undefined).

run_command_in_dir(Program, Args, Cwd) ->
    ProgramStr = binary_to_list(Program),
    case os:find_executable(ProgramStr) of
        false ->
            {error, <<"Command not found: ", Program/binary>>};
        Path ->
            try
                ArgsStr = [binary_to_list(A) || A <- Args],
                BaseOpts = [{args, ArgsStr}, exit_status, binary,
                            stderr_to_stdout, use_stdio],
                Opts = case Cwd of
                    undefined -> BaseOpts;
                    _ -> [{cd, binary_to_list(Cwd)} | BaseOpts]
                end,
                Port = open_port(
                    {spawn_executable, Path},
                    Opts
                ),
                collect_output(Port, <<>>)
            catch
                _:Reason ->
                    {error, list_to_binary(
                        io_lib:format("~p", [Reason]))}
            end
    end.

collect_output(Port, Acc) ->
    receive
        {Port, {data, Data}} ->
            collect_output(Port, <<Acc/binary, Data/binary>>);
        {Port, {exit_status, Status}} ->
            % stderr_to_stdout merges stderr into stdout,
            % so stderr is always empty here
            {ok, {Status, Acc, <<>>}}
    after 300000 ->
        catch port_close(Port),
        {error, <<"Command timed out after 300 seconds">>}
    end.
