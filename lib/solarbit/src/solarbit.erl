-module(solarbit).

-include("solarbit.hrl").
-export([start/0, stop/0, miners/0, info/0, send/2, coinbase/0, connect/1, remote/1, remote/2]).


start() ->
	application:start(solarbit).


stop() ->
	application:stop(solarbit).


miners() ->
	sbt_pool_srv:miners().


info() ->
	sbt_pool_srv:state().


coinbase() ->
	{ok, Miners} = miners(),
	[{Host, sbt_pool_srv:coinbase(Miner)} || Miner = #miner{ip = Host} <- Miners].


send(Miner, ping) ->
	sbt_pool_srv:send(Miner, #message{type = <<"PING">>});
send(Miner, stat) ->
	sbt_pool_srv:send(Miner, #message{type = <<"STAT">>});
send(Miner, test) ->
	sbt_pool_srv:send(Miner, #message{type = <<"TEST">>, payload = ?TEST_BLOCK}).


connect(Node) ->
	pong == net_adm:ping(Node).


remote(Command) ->
	case nodes() of
	[Node] ->
		rpc:call(Node, solarbit, Command, [], 3000);
	[] ->
		error
	end.

remote(Miner, Command) ->
	case nodes() of
	[Node] ->
		rpc:cast(Node, solarbit, send, [Miner, Command]);
	[] ->
		error
	end.
