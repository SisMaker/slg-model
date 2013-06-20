%% 实现ets表保存逻辑.
%% EtsHolder -> 兼职id分配.
-module(data_holder).
-compile([export_all]).

-include_lib("eunit/include/eunit.hrl").
-include("model.hrl").

start_link(DataBase, Key) ->
  Atom = model:atom(holder, Key),
  gen_server:start_link({local, Atom}, ?MODULE, [DataBase, Key], []).

id(Key) ->
  Atom = model:atom(holder, Key),
  gen_server:call(Atom, id).

stop(Key) ->
  Atom = model:atom(holder, Key),
  gen_server:cast(Atom, stop).

%% 读取数据库，获得Table表的最大id.
max_id(Poll, Table) ->
  model:max_id(Poll, Table).

init([Dbc, Key]) ->
  data_ets:new(Key),
  model:module_new(Key),
  model:start(Dbc#db_conf{poll=model:atom(read, Key), worker=3}),
  model:start(Dbc#db_conf{poll=model:atom(write, Key), worker=1}),
  MaxId = max_id(model:atom(read, Key), Key),
  io:format("max id ~p~n", [MaxId]),
  data_guard_super:start_guard(Key),
  data_writer_super:start_writer(Key),
  data_clear_super:start_clear(Key),
  {ok, {Key, MaxId, Dbc}}.

handle_cast(stop, State) ->
  {stop, normal, State};
handle_cast(_, State) ->
  {noreply, State}.

handle_call(id, _From, {Key, MaxID, Dbc}) ->
  Base = Dbc#db_conf.base,
  %% id策略还没考虑进来
  OID = MaxID div Base,
  SID = MaxID rem Base,
  io:format("id ~p ~p~n", [OID, SID]),
  MaxID1 = (OID+1) * Base + SID,
  io:format("id ~p~n", [MaxID1]),
  {reply, MaxID1, {Key, MaxID1, Dbc}};

handle_call(_Msg, _From, State) ->
  {reply, ok, State}.

handle_info(_Info, State) ->
  %% {stop, normal, State}.
  {noreply, State}.

code_change(_OldVsn, State, _Extra) ->
  {ok, State}.
terminate(_Reason, _State) ->
  ok.
