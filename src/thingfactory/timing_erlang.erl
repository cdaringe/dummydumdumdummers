-module(timing_erlang).
-export([get_current_time_ms/0]).

% Get current time in milliseconds using Erlang's system time
% Returns an integer representing milliseconds since epoch
get_current_time_ms() ->
  erlang:system_time(millisecond).
