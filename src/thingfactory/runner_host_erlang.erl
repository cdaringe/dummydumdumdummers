-module(runner_host_erlang).
-export([get_cpu_count/0]).

% Detect available logical CPU cores for worker pool sizing.
% Returns an integer representing the number of available cores.
get_cpu_count() ->
    erlang:system_info(logical_processors).
