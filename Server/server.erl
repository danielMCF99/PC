-module(server).
-export([start/0,server/1]).
-import(login_manager,[start_login/0]).
-import(user_manager,[userAuth/1]).
-import(score_manager,[scoreBoard/2]).

start() -> server(4321).

server(Port)->
   register(match_manager, spawn(fun() -> roomMatch([], [], 3) end)),
   register(login_manager, start_login()),
   register(score_manager, spawn(fun() -> scoreBoard([], self()) end)),
   {ok, LSock} = gen_tcp:listen(Port, [binary, {packet, line}, {reuseaddr, true}]),
   io:format("Servidor pronto.~n", []),
   acceptor(LSock).

acceptor(LSock) ->
   {ok, Sock} = gen_tcp:accept(LSock),
   spawn(fun() -> acceptor(LSock) end),
   io:format("Alguem entrou.~n", []),
   userAuth(Sock).

roomMatch(ActivePlayers, WaitingQueue, MaxPlayers) ->
   receive
      {newPlayer, User, Pid} ->
         roomMatch(ActivePlayers,WaitingQueue,MaxPlayers);

      {login, User, Pid} ->
         PlayerCheck = {Pid, User},
         Condition2 = lists:member(PlayerCheck, ActivePlayers),
         if
            Condition2 ->
               WaitingQueue1 = WaitingQueue;
            true ->
               WaitingQueue1 = WaitingQueue ++ [{Pid, User}]
         end,

         if
            length(ActivePlayers) < MaxPlayers ->
               io:format("User ~s wants to play. Waiting for opponent...~n", [User]),
               if
                  length(WaitingQueue1) < 1 ->
                     roomMatch(ActivePlayers, WaitingQueue1, MaxPlayers);
                  true ->
                     Player = lists:nth(1,WaitingQueue1),
                     WaitingQueue2 = lists:delete(Player, WaitingQueue1),
                     Condition = lists:member(Player, ActivePlayers),
                     if
                        Condition ->
                           ActivePlayers1 = ActivePlayers;
                        true ->
                           ActivePlayers1 = [Player | ActivePlayers]
                     end,
                     if
                        length(ActivePlayers1) == MaxPlayers ->
                           io:format("Opponents found~n", []),
                           matchInitialize(ActivePlayers1, maps:new(), [], maps:new(), []),
                           roomMatch(ActivePlayers1, WaitingQueue2, MaxPlayers);
                        true ->
                           roomMatch(ActivePlayers1, WaitingQueue2, MaxPlayers)
                     end

               end;

            true ->
               roomMatch(ActivePlayers, WaitingQueue1, MaxPlayers)
         end;

      {continue, User, Pid} ->
         Condition = lists:member({Pid, User}, WaitingQueue),
         if
            Condition ->
               WaitingQueue1 = WaitingQueue;
            true ->
               WaitingQueue1 = [{Pid, User} | WaitingQueue]
         end,
         ActivePlayers1 = lists:delete({Pid,User},ActivePlayers),
         if
            length(WaitingQueue1) > 0 ->
               Player = lists:nth(1,WaitingQueue1),
               WaitingQueue2 = lists:delete(Player, WaitingQueue1),
               Condition2 = lists:member(Player, ActivePlayers),
               if
                  Condition2 ->
                     ActivePlayers2 = ActivePlayers1;
                  true ->
                     ActivePlayers2 = [Player | ActivePlayers1]
               end,

               if
                  length(ActivePlayers2) == MaxPlayers ->
                     io:format("Opponents found~n", []),
                     matchInitialize(ActivePlayers2, maps:new(), [], maps:new(),[]),
                     roomMatch(ActivePlayers2, WaitingQueue2, MaxPlayers);
                  true ->
                     roomMatch(ActivePlayers2, WaitingQueue2, MaxPlayers)
               end;
            true ->
               roomMatch(ActivePlayers, WaitingQueue1, MaxPlayers)
         end;

      {leaveWaitMatch, User, Pid} ->
         io:format("User ~s left server~n", [User]),
         roomMatch(ActivePlayers -- [{Pid, User}], WaitingQueue, MaxPlayers)
   end.

%Função para garantir que não há sobreposição de spawns de criaturas/jogadores ao começar
checkPosition(_, _, _, []) ->
   true;
checkPosition(X, Y, Radius, [{_,Player} | Players]) ->
   {ok, X2} = maps:find(x, Player),
   {ok, Y2} = maps:find(y, Player),
   {ok, Radius2} = maps:find(radius, Player),
   Dist = math:sqrt(math:pow(X2 - X, 2) + math:pow(Y2 - Y, 2)),
   if
      Dist < Radius2 + Radius ->
         false;
      true ->
         checkPosition(X, Y, Radius, Players)
   end.

% Função que cria os objetos iniciais
createCreature(_, 0, _, Res) ->
   Res;
createCreature(Type, N, Players, Res) ->
   X = rand:uniform(1367)-1,
   Y = rand:uniform(769)-1,
   Radius = rand:uniform(15)+3,
   Bool = checkPosition(X, Y, Radius, Players),
   if
      not Bool ->
         createCreature(Type, N, Players, Res);
      true ->
         Creature = maps:new(),
         Creature2 = maps:put(type, Type, Creature),
         Creature3 = maps:put(x, X, Creature2),
         Creature4 = maps:put(y, Y, Creature3),
         Creature5 = maps:put(radius, Radius, Creature4),
         NewRes = [Creature5 | Res],
         createCreature(Type, N-1, Players, NewRes)
   end.

% Função que cria um jogador
createPlayer(Username, Players, PressedKeys, BestScore) ->
   X = rand:uniform(1367)-1,
   Y = rand:uniform(769)-1,
   Radius = 20,
   Bool = checkPosition(X, Y, Radius, Players),
   if
      BestScore == 0 ->
         BestScore1 = 5 * math:pi() * Radius * Radius;
      true ->
         BestScore1 = BestScore
   end,
   if
      not Bool ->
         createPlayer(Username, Players, PressedKeys, BestScore1);
      true ->
         Player = maps:new(),
         Player2 = maps:put(username, Username, Player),
         Player3 = maps:put(x, X, Player2),
         Player4 = maps:put(y, Y, Player3),
         Player5 = maps:put(radius, Radius, Player4),
         Player6 = maps:put(score, 5 * math:pi() * Radius * Radius, Player5),
         Player7 = maps:put(pressedKeys, PressedKeys, Player6),
         Player8 = maps:put(bestScore, BestScore1, Player7),
         Player8
   end.

eatingEventCreature(Player, Creature) ->
   {ok, XP} = maps:find(x, Player),
   {ok, YP} = maps:find(y, Player),
   {ok, RP} = maps:find(radius, Player),
   {ok, XC} = maps:find(x, Creature),
   {ok, YC} = maps:find(y, Creature),
   {ok, RC} = maps:find(radius, Creature),
   {ok, Type} = maps:find(type, Creature),
   Dist = math:sqrt(math:pow(XC - XP, 2) + math:pow(YC - YP, 2)),
   case Type of
      food ->
         % Sobreposição total
         if
            Dist < RP - RC andalso RP > RC ->
               SizeP = math:pi() * RP * RP,
               SizeC = math:pi() * RC * RC,
               Res = math:sqrt((SizeP + SizeC)/math:pi()) - RP,
               {true, Res};
            true ->
               false
         end;
      poison ->
         % Sobreposição parcial
         if
            Dist < RP + RC andalso RP > RC ->
               SizeP = math:pi() * RP * RP,
               SizeC = math:pi() * RC * RC,
               Res = math:sqrt((SizeP - SizeC)/math:pi()) - RP,
               {true, Res};
            true ->
               false
         end
   end.


% Função que devolve uma lista dos índices dos objetos comidos e uma lista sem eles
creaturesEaten(Player, [], _, {IdxFood, IdxPoison, RadiusChange, NewCreatures}) ->
   {IdxFood, IdxPoison, RadiusChange, NewCreatures, Player};
creaturesEaten(Player, [empty | Creatures], Idx, {IdxFood, IdxPoison, RadiusChange, NewCreatures}) ->
   creaturesEaten(Player, Creatures, Idx+1, {IdxFood, IdxPoison, RadiusChange, NewCreatures});
creaturesEaten(Player, [Creature | Creatures], Idx, {IdxFood, IdxPoison, RadiusChange, NewCreatures}) ->
   case eatingEventCreature(Player, Creature) of
      {true, RadiusDiff} ->
         NewCreatures1 = lists:sublist(NewCreatures, Idx-1) ++ [empty] ++ lists:nthtail(Idx, NewCreatures),
         case maps:find(type, Creature) of
            {ok, poison} ->
               creaturesEaten(Player, Creatures, Idx+1, {IdxFood, [Idx|IdxPoison], RadiusChange + RadiusDiff, NewCreatures1});
            {ok, food} ->
               creaturesEaten(Player, Creatures, Idx+1, {[Idx|IdxFood], IdxPoison, RadiusChange + RadiusDiff, NewCreatures1})
         end;
      false ->
         creaturesEaten(Player, Creatures, Idx+1, {IdxFood, IdxPoison, RadiusChange, NewCreatures})
   end.

% Função que verifica que objetos foram comidos e devolve o índice deles
verifyCreaturesEaten([], _, Res) ->
   Res;
verifyCreaturesEaten([{Pid, Player}|T], Creatures, {Food, Poison, PlayersRadiusChange, UpdatedPlayers}) ->
   MinRadius = 16,
   {IdxFood, IdxPoison, RadiusChange, NewCreatures, NewPlayer} = creaturesEaten(Player, Creatures, 1, {[], [], 0, Creatures}),
   UpdatedPlayers1 = maps:put(Pid, NewPlayer, UpdatedPlayers),
   {ok, PlayerRadius} = maps:find(radius, NewPlayer),
   if
      PlayerRadius + RadiusChange =< MinRadius ->
         verifyCreaturesEaten(T, NewCreatures, {IdxFood++Food, IdxPoison++Poison, [{Pid, MinRadius - PlayerRadius}|PlayersRadiusChange], UpdatedPlayers1});
      true ->
         verifyCreaturesEaten(T, NewCreatures, {IdxFood++Food, IdxPoison++Poison, [{Pid, RadiusChange}|PlayersRadiusChange], UpdatedPlayers1})
   end.


% Função que verifica se um jogador come outro jogador. Em caso afirmativo, devolve o aumento no raio
eatingEventPlayer(Player1, Player2) ->
   {ok, XP1} = maps:find(x, Player1),
   {ok, YP1} = maps:find(y, Player1),
   {ok, RP1} = maps:find(radius, Player1),
   {ok, XP2} = maps:find(x, Player2),
   {ok, YP2} = maps:find(y, Player2),
   {ok, RP2} = maps:find(radius, Player2),
   Dist = math:sqrt(math:pow(XP2 - XP1, 2) + math:pow(YP2 - YP1, 2)),
   if
      RP1 > RP2 andalso Dist < RP1 - RP2 ->
         SizeP1 = math:pi() * RP1 * RP1,
         SizeP2 = math:pi() * RP2 * RP2,
         Res = math:sqrt((SizeP1 + (SizeP2/4))/math:pi()) - RP1,
         {true, Res};
      true ->
         false
   end.

% Função que devolve uma lista dos Pid's dos jogadores comidos por um outro jogador
playersEaten(_, [], _, Res) ->
   Res;
playersEaten(Player, [dead | Players], Idx, {DeadPlayersPids, RadiusChange, NewPlayers}) ->
   playersEaten(Player, Players, Idx+1, {DeadPlayersPids, RadiusChange, NewPlayers});
playersEaten(Player1, [{Pid, Player2} | Players], Idx, {DeadPlayersPids, RadiusChange, NewPlayers}) ->
   case eatingEventPlayer(Player1, Player2) of
      {true, RadiusDiff} ->
         NewPlayers1 = lists:sublist(NewPlayers, Idx-1) ++ [dead] ++ lists:nthtail(Idx, NewPlayers),
         playersEaten(Player1, Players, Idx+1, {[Pid|DeadPlayersPids], RadiusChange + RadiusDiff, NewPlayers1});
      false ->
         playersEaten(Player1, Players, Idx+1, {DeadPlayersPids, RadiusChange, NewPlayers})
   end.

% Função que verifica que jogadores foram comidos e devolve o índice deles
verifyPlayersEaten([], _, Res) ->
   Res;
verifyPlayersEaten([{Pid, Player}|T], Players, {DeadPlayers, PlayersRadiusChange}) ->
   {DeadPlayersPids, RadiusChange, NewPlayers} = playersEaten(Player, Players, 1, {[], 0, Players}),
   verifyPlayersEaten(T, NewPlayers, {DeadPlayers ++ DeadPlayersPids, [{Pid, RadiusChange}|PlayersRadiusChange]}).


% Função que atualiza o tamanho e a pontuação dos jogadores ou coloca-os de novo em jogo (caso tenham sido capturados)
updatePlayers(_, [], [], Res) ->
   Res;
updatePlayers(Players, [], [Dead|T], Res) ->
   {ok, Player} = maps:find(Dead, Players),
   {ok, Username} = maps:find(username, Player),
   {ok, BestScore} = maps:find(bestScore, Player),
   Keys = maps:new(),
   Keys1 = maps:put(up, false ,Keys),
   Keys2 = maps:put(down, false ,Keys1),
   Keys3 = maps:put(left, false ,Keys2),
   Keys4 = maps:put(right, false ,Keys3),
   NewPlayer = createPlayer(Username, maps:to_list(Res), Keys4, BestScore),
   Res1 = maps:put(Dead, NewPlayer, Res),
   updatePlayers(Players, [], T, Res1);
updatePlayers(Players, [{Pid, Change}|T], DeadPlayers, Res) ->
   {ok, Player} = maps:find(Pid, Players),
   {ok, PlayerRadius} = maps:find(radius, Player),
   {ok, Username} = maps:find(username, Player),
   {ok, BestScore} = maps:find(bestScore, Player),
   NewPlayer1 = maps:put(radius, PlayerRadius + Change, Player),
   {ok, R} = maps:find(radius, NewPlayer1),
   NewScore = 5 * math:pi() * R * R,
   score_manager ! {newScore, {Username, NewScore}},
   NewPlayer2 = maps:put(score, NewScore, NewPlayer1),
   if
      NewScore > BestScore ->
         NewPlayer3 = maps:put(bestScore, NewScore, NewPlayer2);
      true ->
         NewPlayer3 = NewPlayer2
   end,
   Res1 = maps:put(Pid, NewPlayer3, Res),
   updatePlayers(Players, T, DeadPlayers, Res1).


% Função que substitui os objetos capturados por objetos novos
replaceCreatures(Res, [], []) ->
   Res;
replaceCreatures(Res, [Creature|T], [Idx|Indices]) ->
   Res1 = lists:sublist(Res, Idx-1) ++ [Creature] ++ lists:nthtail(Idx, Res),
   replaceCreatures(Res1, T, Indices).

% Função que calcula as interações entre os jogadores e os objetos/jogadores, alterando o tamanho dos jogadores e devolvendo o número de objetos comidos de cada tipo
interactions(MatchInfo) ->
   {ok, Players} = maps:find(players, MatchInfo),
   {ok, Creatures} = maps:find(creatures, MatchInfo),

   % Verificar se os jogadores comem criaturas
   {FoodIndices, PoisonIndices, PlayersRadiusChange, UpdatedPlayers} = verifyCreaturesEaten(maps:to_list(Players), Creatures, {[], [], [], Players}),
   NewPlayers = updatePlayers(UpdatedPlayers, PlayersRadiusChange, [], maps:new()),

   % Verificar se os jogadores comem outros jogadores
   {DeadPlayers, PlayersRadiusChange1} = verifyPlayersEaten(maps:to_list(NewPlayers), maps:to_list(NewPlayers), {[], []}),
   NewPlayers1 = updatePlayers(NewPlayers, PlayersRadiusChange1, DeadPlayers, maps:new()),

   % Atualizar a informação resultante
   MatchInfo1 = maps:update(players, NewPlayers1, MatchInfo),
   NewCreatures = createCreature(food, length(FoodIndices), maps:to_list(NewPlayers1), []) ++ createCreature(poison, length(PoisonIndices), maps:to_list(NewPlayers1), []),
   Creatures1 = replaceCreatures(Creatures, NewCreatures, FoodIndices ++ PoisonIndices),
   MatchInfo2 = maps:update(creatures, Creatures1, MatchInfo1),
   UpdatedPlayersPids = lists:merge([lists:sort(PlayersRadiusChange), lists:sort(PlayersRadiusChange1), lists:map(fun(Pid) -> {Pid, -1} end, lists:sort(DeadPlayers))]),
   UpdatedPlayersPids1 = lists:map(fun({Pid, _}) -> Pid end, lists:filter(fun({_, RadiusChange}) -> RadiusChange /= 0 end, UpdatedPlayersPids)),
   {MatchInfo2, FoodIndices ++ PoisonIndices, UpdatedPlayersPids1}.


% Função que inicializa uma partida
matchInitialize([], Players, Pids, PressedKeys, Scores) ->
   PidMatch = self(),

   MatchSender = spawn(fun() ->

      Creatures = createCreature(poison, 50, maps:to_list(Players), []) ++ createCreature(food, 50, maps:to_list(Players), []),
      Info = maps:new(),
      Info1 = maps:put(players,Players, Info),
      Info2 = maps:put(creatures,Creatures, Info1),
      Match = maps:put(scores,Scores, Info2),
      [Player ! {initialMatch, Match, PidMatch, match_manager} || Player <- Pids],
      matchSender(Match, Pids, PidMatch, false)
                       end),
   match(PressedKeys, Pids, MatchSender);
matchInitialize([{Pid, Username}|T], Players, Pids, PressedKeys, Scores) ->
   Keys = maps:new(),
   Keys1 = maps:put(up, false ,Keys),
   Keys2 = maps:put(down, false ,Keys1),
   Keys3 = maps:put(left, false ,Keys2),
   PlayerPressedKeys = maps:put(right, false ,Keys3),
   PlayerData = createPlayer(Username, maps:to_list(Players), PlayerPressedKeys, 0),
   ScoresInfo = {maps:get(username, PlayerData),maps:get(score, PlayerData)},
   Scores2 = [ScoresInfo | Scores],
   NewPlayers = maps:put(Pid, PlayerData, Players),
   NewPressedKeys = maps:put(Pid, PlayerPressedKeys, PressedKeys),
   matchInitialize(T, NewPlayers, [Pid | Pids], NewPressedKeys, Scores2).


% Função que gere uma partida entre vários utilizadores
match(PressedKeys, PlayersPids, MatchSender) ->
   receive
      {(keyChanged), Key, Change, Pid} ->
         {ok, PlayerKeys} = maps:find(Pid, PressedKeys),
         case Change of
            false ->
               case Key of
                  "up" ->
                     PlayerKeys1 = maps:update(up, false, PlayerKeys),
                     PressedKeys1 = maps:update(Pid, PlayerKeys1, PressedKeys),
                     MatchSender ! {Pid, PlayerKeys1},
                     match(PressedKeys1, PlayersPids, MatchSender);
                  "down" ->
                     PlayerKeys1 = maps:update(down, false, PlayerKeys),
                     PressedKeys1 = maps:update(Pid, PlayerKeys1, PressedKeys),
                     MatchSender ! {Pid, PlayerKeys1},
                     match(PressedKeys1, PlayersPids, MatchSender);
                  "left" ->
                     PlayerKeys1 = maps:update(left, false, PlayerKeys),
                     PressedKeys1 = maps:update(Pid, PlayerKeys1, PressedKeys),
                     MatchSender ! {Pid, PlayerKeys1},
                     match(PressedKeys1, PlayersPids, MatchSender);
                  "right" ->
                     PlayerKeys1 = maps:update(right, false, PlayerKeys),
                     PressedKeys1 = maps:update(Pid, PlayerKeys1, PressedKeys),
                     MatchSender ! {Pid, PlayerKeys1},
                     match(PressedKeys1, PlayersPids, MatchSender)
               end;
            true ->
               case Key of
                  "up" ->
                     PlayerKeys1 = maps:update(up, true, PlayerKeys),
                     PressedKeys1 = maps:update(Pid, PlayerKeys1, PressedKeys),
                     MatchSender ! {Pid, PlayerKeys1},
                     match(PressedKeys1, PlayersPids, MatchSender);
                  "down" ->
                     PlayerKeys1 = maps:update(down, true, PlayerKeys),
                     PressedKeys1 = maps:update(Pid, PlayerKeys1, PressedKeys),
                     MatchSender ! {Pid, PlayerKeys1},
                     match(PressedKeys1, PlayersPids, MatchSender);
                  "left" ->
                     PlayerKeys1 = maps:update(left, true, PlayerKeys),
                     PressedKeys1 = maps:update(Pid, PlayerKeys1, PressedKeys),
                     MatchSender ! {Pid, PlayerKeys1},
                     match(PressedKeys1, PlayersPids, MatchSender);
                  "right" ->
                     PlayerKeys1 = maps:update(right, true, PlayerKeys),
                     PressedKeys1 = maps:update(Pid, PlayerKeys1, PressedKeys),
                     MatchSender ! {Pid, PlayerKeys1},
                     match(PressedKeys1, PlayersPids, MatchSender)
               end
         end;

      {leave, User, Pid} ->
         MatchSender ! {exit, User, Pid}
   end.

% Função que atualiza a informação da partida e a envia aos clientes
matchSender(Match, PlayersPids, PidMatch, ScoresUpdated) ->
   receive
      {scores, Scores} ->
         Match1 = maps:update(scores, Scores, Match),
         matchSender(Match1, PlayersPids, PidMatch, true);

      {Pid, PressedKeys} ->
         {ok, Players} = maps:find(players, Match),
         {ok, Player} = maps:find(Pid, Players),
         Player1 = maps:update(pressedKeys, PressedKeys, Player),
         Players1 = maps:update(Pid, Player1, Players),
         Match1 = maps:update(players, Players1, Match),
         matchSender(Match1, PlayersPids, PidMatch, ScoresUpdated);

      {exit, User, Pid} ->
         {ok, Players} = maps:find(players, Match),
         Leaderboard = leaderboard(maps:to_list(Players), []),
         [Player ! {matchOver, Leaderboard, PidMatch} || Player <- PlayersPids],
         score_manager ! {getScores, self()},
         match_manager ! {leaveWaitMatch, User, Pid},
         done
      after
         30 ->
            Match1 = sendSimulation(Match, PlayersPids, PidMatch, ScoresUpdated),
            matchSender(Match1, PlayersPids, PidMatch, false)
   end.

% Função que devolve a tabela de pontuações de uma partida
leaderboard([], Res) ->
   lists:sort(fun({_, Score1}, {_, Score2}) -> Score1 >= Score2 end, Res);
leaderboard([{_, Player}|Tail], Res) ->
   {ok, Username} = maps:find(username, Player),
   {ok, Score} = maps:find(bestScore, Player),
   leaderboard(Tail, [{Username, Score}|Res]).


% Função que atualiza a posição dos jogadores, tendo em conta as teclas pressionadas por estes
updatePosition(X, Y, _, _, []) ->
   {X,Y};
updatePosition(X, Y, Acc, Radius, [{K,true}|Keys]) ->
   case K of
      up ->
         Y1 = Y - 2,
         Y2 = max(Y1, 0),
         X2 = X;
      down ->
         Y1 = Y + 2,
         Y2 = min(Y1, 768),
         X2 = X;
      left ->
         X1 = X - 2,
         X2 = max(X1, 0),
         Y2 = Y;
      right ->
         X1 = X + 2,
         X2 = min(X1, 1366),
         Y2 = Y
   end,
   updatePosition(X2, Y2, Acc, Radius, Keys).


% Função que atualiza a informação dos jogadores, tendo em conta as teclas pressionadas por estes
keyPressedEvent([], Res, UpdatedPlayers) ->
   {Res, UpdatedPlayers};
keyPressedEvent([{Pid,PlayerData}|Players], Res, UpdatedPlayers) ->
   {ok, PressedKeys} = maps:find(pressedKeys, PlayerData),
   {ok, Radius} = maps:find(radius, PlayerData),
   {ok, X} = maps:find(x, PlayerData),
   {ok, Y} = maps:find(y, PlayerData),
   Acc = 1/(Radius * Radius * math:pi()) + 3,
   TrueKeys = maps:filter(fun(_, V) ->
      case V of
         true ->
            true;
         _ ->
            false
      end end, PressedKeys),
   {X1, Y1} = updatePosition(X, Y, Acc, Radius, maps:to_list(TrueKeys)),
   PD1 = maps:update(x, X1, PlayerData),
   PD2 = maps:update(y, Y1, PD1),
   Res1 = maps:put(Pid, PD2, Res),
   case {X1, Y1} of
      {X, Y} ->
         PlayerWasUpdated = false; %nao ha movimento
      _ ->
         PlayerWasUpdated = true
   end,
   if
      PlayerWasUpdated ->
         UpdatedPlayers1 = [Pid|UpdatedPlayers];
      true ->
         UpdatedPlayers1 = UpdatedPlayers
   end,
   keyPressedEvent(Players, Res1, UpdatedPlayers1).

% Função que simula a partida num dado momento, enviando o resultado obtido aos jogadores
sendSimulation(Match, PlayersPids, PidMatch, ScoresUpdated) ->
   UpdatedInfo = maps:new(),

   % Atualizar a posição dos jogadores e o estado dos bónus
   {ok, Players} = maps:find(players, Match),
   {Players1, UpdatedPlayersPids1} = keyPressedEvent(maps:to_list(Players), maps:new(), []),
   Match2 = maps:update(players, Players1, Match),

   % Verificar se os jogadores comem blobs ou outros jogadores, atualizando as suas pontuações e tamanhos
   {Match3, UpdatedCreatures, UpdatedPlayersPids2} = interactions(Match2),
   UpdatedInfo2 = updatePlayersCreaturesInfo(Match3, UpdatedInfo, UpdatedCreatures, lists:merge(lists:sort(UpdatedPlayersPids1), lists:sort(UpdatedPlayersPids2)), [], maps:new()),

   % Atualizar as melhores pontuações, se tiverem sido atualizadas pelo gestor de pontuações
   case ScoresUpdated of
      true ->
         io:format("Entrou no if caso as melhores pontuacoes atualizaram~n",[]),
         {ok, Scores} = maps:find(scores, Match),
         UpdatedInfo3 = maps:put(scores, Scores, UpdatedInfo2),
         % Enviar as informações atualizadas aos jogadores, se estas exitirem
         Size = maps:size(UpdatedInfo3),
         if
            Size == 0 ->
               nothingToSend;
            true ->
               [Player ! {updateMatch, UpdatedInfo3, PidMatch} || Player <- PlayersPids]
         end;

      false ->
         UpdatedInfo3 = UpdatedInfo2,
         % Enviar as informações atualizadas aos jogadores, se estas exitirem
         Size = maps:size(UpdatedInfo3),
         if
            Size == 0 ->
               nothingToSend;
            true ->
               [Player ! {updateMatch, UpdatedInfo3, PidMatch} || Player <- PlayersPids]
         end

   end,
   Match3.

% Função que guarda a informação dos jogadores e dos objetos que foi alterada
updatePlayersCreaturesInfo(_, Res, [], [], TmpCreatures, TmpPlayers) ->
   NumCreatures = length(TmpCreatures),
   if
      NumCreatures == 0 ->
         Res1 = Res;
      true ->
         Res1 = maps:put(creatures, TmpCreatures, Res)
   end,
   NumPlayers = maps:size(TmpPlayers),
   if
      NumPlayers == 0 ->
         Res2 = Res1;
      true ->
         Res2 = maps:put(players, TmpPlayers, Res1)
   end,
   Res2;
updatePlayersCreaturesInfo(MatchInfo, Res, [], [P|RemainingPlayers], TmpCreatures, TmpPlayers) ->
   {ok, Players} = maps:find(players, MatchInfo),
   {ok, Player} = maps:find(P, Players),
   TmpPlayers1 = maps:put(P, Player, TmpPlayers),
   updatePlayersCreaturesInfo(MatchInfo, Res, [], RemainingPlayers, TmpCreatures, TmpPlayers1);
updatePlayersCreaturesInfo(MatchInfo, Res, [B|RemainingCreatures], UpdatedPlayers, TmpCreatures, TmpPlayers) ->
   {ok, Creatures} = maps:find(creatures, MatchInfo),
   updatePlayersCreaturesInfo(MatchInfo, Res, RemainingCreatures, UpdatedPlayers, [{B-1, lists:nth(B, Creatures)}|TmpCreatures], TmpPlayers).