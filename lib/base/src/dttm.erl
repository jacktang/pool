% Copyright 2016 Steve Davis <steve@solarbit.cc>
% See MIT LICENSE

-module(dttm).

%@ref rfc1123
%@ref rfc3339
%@ref iso8601

-include("base.hrl").

-compile(export_all).
-export([now/0, date/1, date/2, datetime/1, datetime/2, timestamp/0, timestamp/1, parse/1, format/1]).

-export([encode/1, decode/1]).

-define(UNIX_EPOCH_ZERO, 62167219200).

%% TODO: Consider - dttm:date(dttm:decode(<<"Mon, 22 Jul 2013 22:46:11 GMT">>)) -> <<"Tue, 23 Jul 2013 03:46:11 GMT">>!

format(Epoch) ->
	DateTime = calendar:gregorian_seconds_to_datetime(?UNIX_EPOCH_ZERO + Epoch),
	list_to_binary(to_iso8601(DateTime, "Z")).


now() ->
	{M, S, _} = erlang:timestamp(),
	M * 1000000 + S.


millis() ->
	{M, S, U} = erlang:timestamp(),
	M * 1000000000 + S * 1000 + U div 1000.


unow() ->
    calendar:datetime_to_gregorian_seconds(calendar:universal_time()).


date(iso8601) ->
	timestamp();
date(rfc3339) ->
	timestamp();
date(rfc1123) ->
	date(rfc1123, calendar:universal_time()).

date(rfc1123, {Date = {Y, Mo, D}, {H, M, S}}) ->
	DayOfWeek = encode_rfc1123_day_of_week0(calendar:day_of_the_week(Date)),
	SP = <<" ">>,
	list_to_binary([
		DayOfWeek, $,, SP,
		encode_dttm_part(D), SP,
		encode_rfc1123_month(Mo), SP,
		encode_dttm_part(Y), SP,
		encode_dttm_part(H), $:,
		encode_dttm_part(M), $:,
		encode_dttm_part(S),
		<<" GMT">>
	]).


encode_dttm_part(X) ->
	case text:encode(X) of
	<<T>> ->
		<<$0, T>>;
	Bin ->
		Bin
	end.


to_seconds(DTTM = {_, _}) ->
	calendar:datetime_to_gregorian_seconds(DTTM) - ?UNIX_EPOCH_ZERO;

to_seconds(Date = {_, _, _}) ->
	calendar:datetime_to_gregorian_seconds({Date, {0,0,0}}) - ?UNIX_EPOCH_ZERO.


datetime() ->
	datetime(dttm:now()).

datetime(Seconds) ->
	datetime(unix, Seconds).

datetime(Type, Seconds) when is_atom(Type), is_integer(Seconds) ->
	Seconds0 = convert_seconds(Type, Seconds),
	calendar:gregorian_seconds_to_datetime(Seconds0).


convert_seconds(unix, Seconds) ->
	?UNIX_EPOCH_ZERO + Seconds;
convert_seconds(universal, Seconds) ->
	Seconds.


timestamp() ->
	timestamp(calendar:universal_time()).
timestamp({Y, Mo, D, H, M, S}) ->
	timestamp({{Y, Mo, D}, {H, M, S}});
timestamp(Seconds) when is_integer(Seconds) ->
	timestamp(calendar:gregorian_seconds_to_datetime(Seconds + ?UNIX_EPOCH_ZERO));
timestamp(DateTime = {_, _}) ->
	list_to_binary(to_iso8601(DateTime, "Z")).


to_iso8601({{Year, Month, Day}, {Hour, Min, Sec}}, Zone) ->
	ISO_8601 = "~4.10.0B-~2.10.0B-~2.10.0BT~2.10.0B:~2.10.0B:~2.10.0B~s",
	io_lib:format(ISO_8601, [Year, Month, Day, Hour, Min, Sec, Zone]).


encode(D = {_, _, _}) ->
	encode(D, $-);
encode({D = {_, _, _}, T = {_, _, _}}) ->
	list_to_binary([encode(D, $-), $T, encode(T, $:), $Z]).
encode({Y, M, D}, Separator) ->
	list_to_binary([text:encode(Y), Separator, text:encode(M), Separator, text:encode(D)]).


encode_rfc1123_day_of_week0(N) when is_integer(N) ->
	lists:nth(N, [<<"Mon">>, <<"Tue">>, <<"Wed">>, <<"Thu">>, <<"Fri">>, <<"Sat">>, <<"Sun">>]).

encode_rfc1123_day_of_week(1) -> <<"Mon">>;
encode_rfc1123_day_of_week(2) -> <<"Tue">>;
encode_rfc1123_day_of_week(3) -> <<"Wed">>;
encode_rfc1123_day_of_week(4) -> <<"Thu">>;
encode_rfc1123_day_of_week(5) -> <<"Fri">>;
encode_rfc1123_day_of_week(6) -> <<"Sat">>;
encode_rfc1123_day_of_week(7) -> <<"Sun">>.

encode_rfc1123_month(1) -> <<"Jan">>;
encode_rfc1123_month(2) -> <<"Feb">>;
encode_rfc1123_month(3) -> <<"Mar">>;
encode_rfc1123_month(4) -> <<"Apr">>;
encode_rfc1123_month(5) -> <<"May">>;
encode_rfc1123_month(6) -> <<"Jun">>;
encode_rfc1123_month(7) -> <<"Jul">>;
encode_rfc1123_month(8) -> <<"Aug">>;
encode_rfc1123_month(9) -> <<"Sep">>;
encode_rfc1123_month(10) -> <<"Oct">>;
encode_rfc1123_month(11) -> <<"Nov">>;
encode_rfc1123_month(12) -> <<"Dec">>.


%*TODO timezone and fractional seconds
% rfc3339/iso8601 <"2012-01-03T14:03:12Z">
decode(<<Y:4/binary, $-, Mo:2/binary, $-, D:2/binary,
		$T, H:2/binary, $:, M:2/binary, $:, S:2/binary, _Bin/binary>>) ->
	[Y0, Mo0, D0, H0, M0, S0] = text:parse_integers([Y, Mo, D, H, M, S]),
	{{Y0, Mo0, D0}, {H0, M0, S0}};
% rfc1123 <"Tue, 03 Jan 2012 14:02:11 GMT">
decode(<<_W:3/binary, ", ", D:2/binary, " ", Mo:3/binary, " ", Y:4/binary, " ",
		H:2/binary, $:, M:2/binary, $:, S:2/binary, " ", "GMT">>) ->
	Mo0 = decode_rfc1123_month(Mo),
	[Y0, D0, H0, M0, S0] = text:parse_integers([Y, D, H, M, S]),
	{{Y0, Mo0, D0}, {H0, M0, S0}};
% rfc1123 <<"Wed, 12 Oct 2011 13:36:35 ?Zone">>
decode(DT = <<_:3/binary, ", ", _/binary>>) ->
	[_, D, Mo, Y, H, M, S, _Zone] = text:split(DT, <<"[ :]">>),
	Mo0 = decode_rfc1123_month(Mo),
	[Y0, D0, H0, M0, S0] = text:parse_integers([Y, D, H, M, S]),
	{{Y0, Mo0, D0}, {H0, M0, S0}};
% Not sure why this is here - is this for AWS?
decode(<<Y:4/binary, Mo:2/binary, D:2/binary, H:2/binary, M:2/binary, S:2/binary>>) ->
	[Y0, Mo0, D0, H0, M0, S0] = text:parse_integers([Y, Mo, D, H, M, S]),
	{{Y0, Mo0, D0}, {H0, M0, S0}};
decode(_) ->
	undefined.


decode_rfc1123_month(<<"Jan">>) -> 1;
decode_rfc1123_month(<<"Feb">>) -> 2;
decode_rfc1123_month(<<"Mar">>) -> 3;
decode_rfc1123_month(<<"Apr">>) -> 4;
decode_rfc1123_month(<<"May">>) -> 5;
decode_rfc1123_month(<<"Jun">>) -> 6;
decode_rfc1123_month(<<"Jul">>) -> 7;
decode_rfc1123_month(<<"Aug">>) -> 8;
decode_rfc1123_month(<<"Sep">>) -> 9;
decode_rfc1123_month(<<"Oct">>) -> 10;
decode_rfc1123_month(<<"Nov">>) -> 11;
decode_rfc1123_month(<<"Dec">>) -> 12.


parse(Bin) ->
	text:split(Bin, <<"([0-9]+)|[, \t\r\n]+">>).
