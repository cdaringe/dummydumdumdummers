-module(command_runner_erlang).
-export([run_command/2]).

% Run a shell command with arguments.
% Returns {ok, {ExitCode, Stdout, Stderr}} or {error, Message}.
run_command(Program, Args) ->
    ProgramStr = binary_to_list(Program),
    case os:find_executable(ProgramStr) of
        false ->
            {error, <<"Command not found: ", Program/binary>>};
        Path ->
            try
                ArgsStr = [binary_to_list(A) || A <- Args],
                Port = open_port(
                    {spawn_executable, Path},
                    [{args, ArgsStr}, exit_status, binary,
                     stderr_to_stdout, use_stdio]
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
