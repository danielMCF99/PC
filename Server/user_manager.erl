-module(user_manager).
-export([userAuth/1]).
-import(login_manager,[login/2,logout/1,create_account/2,close_account/2]).

%Tratar da autenticacao
userAuth(Sock) ->
  receive
    {tcp, _, Data} ->
      Info_without_newline = re:replace(Data,"\\n|\\r", "",[global,{return,list}]),
      Info = string:split(Info_without_newline,",",all),

      case Info of
        ["create_account", User, Pass] ->
          Res = create_account(User, Pass),
          case Res of
            account_created ->
              gen_tcp:send(Sock, io_lib:format("Registered~n", [])),
              match_manager ! {newPlayer, User, self()},
              userAuth(Sock);

            user_exists ->
              gen_tcp:send(Sock, io_lib:format("UserExists~n", [])),
              userAuth(Sock)
          end;

        ["close_account", User, Pass] ->
          Res = close_account(User,Pass),
          case Res of
            account_closed ->
              gen_tcp:send(Sock, io_lib:format("AccountClosed~n", []));
            _ ->
              gen_tcp:send(Sock, io_lib:format("CloseAccountGoneWrong~n", []))
          end;

        ["login", User, Pass] ->
          Res = login(User, Pass),
          case Res of
            login_done ->
              gen_tcp:send(Sock, io_lib:format("LoginDone~n", [])),
              userInGame(Sock, User, newGame(Sock, User));

            already_logged_in ->
              gen_tcp:send(Sock, io_lib:format("AlreadyLoggedIn~n", [])),
              userAuth(Sock);

            login_invalid ->
              gen_tcp:send(Sock, io_lib:format("LoginInvalid~n", [])),
              userAuth(Sock)
          end;

        ["logout", User] ->
          Res = logout(User),
          case Res of
            logout_done ->
              gen_tcp:send(Sock, io_lib:format("LogoutDone~n", []));
            logout_invalid ->
              gen_tcp:send(Sock, io_lib:format("LogoutInvalid~n", []))
          end;

        ["Scores"] ->
          score_manager ! {getScores, self()},
          receive
            {scores, Scores} ->
              gen_tcp:send(Sock, io_lib:format("BeginScores~n", [])),
              ScoresInfo = maps:new(),
              ScoresInfo2 = maps:put(scores,Scores, ScoresInfo),
              sendScores(Sock, ScoresInfo2),
              gen_tcp:send(Sock, io_lib:format("EndScores~n", []));

            _ ->
              gen_tcp:send(Sock, io_lib:format("ScoresInvalid~n", []))
          end,
          userAuth(Sock);

        _ ->
          self() ! gen_tcp:send(Sock, io_lib:format("InvalidCommand~n", []))
      end;

    _ -> userAuth(Sock)
  end.

% Função que devolve uma partida nova
newGame(Sock, User) ->
  match_manager ! {login, User, self()},
  receive
    {initialMatch, MatchInfo, Match, match_manager} ->
      initialInfo(Sock, MatchInfo),
      Match;

    {tcp_closed, _} ->
      io:format("User ~s disconnected~n", [User]),
      logout(User),
      match_manager ! {leaveWaitMatch, User, self()};

    {tcp_error, _, _} ->
      io:format("User ~s disconnected with error~n", [User]),
      logout(User),
      match_manager ! {leaveWaitMatch, User, self()}
  end.

%Funcao para gerir o jogo apos login validado
userInGame(Sock, Username, Match)->
  receive
    {matchOver, ScoreBoard, Match} ->
      matchOver(Sock,Username,ScoreBoard)
  after 0 ->
      receive
        {matchOver, ScoreBoard, Match} ->
          matchOver(Sock,Username,ScoreBoard);

        {updateMatch, UpdateInfo, Match} ->
          sendUpdateInfo(Sock, UpdateInfo),
          userInGame(Sock,Username,Match);

        {tcp, _, Data} ->
          Info_without_newline = re:replace(Data,"\\n|\\r", "",[global,{return,list}]),
          Info = string:split(Info_without_newline,",",all),
          case Info of
          ["KeyChanged", Key, "True"] -> match_manager ! {keyChanged, Key, true, self()};
          ["KeyChanged", Key, "False"] -> match_manager ! {keyChanged, Key, false, self()}
          end,
          userInGame(Sock,Username,Match);

        {tcp_closed, _} ->
          io:format("~s has disconnected~n", [Username]),
          logout(Username),
          match_manager ! {leave, Username, self()};

        {tcp_error, _, _} ->
          io:format("~s left due to error~n", [Username]),
          logout(Username),
          match_manager ! {leave, Username, self()}
      end
  end.

matchOver(Sock, Username, Scoreboard) ->
  gen_tcp:send(Sock, io_lib:format("MatchOverBegin~n", [])),
  Scores = maps:new(),
  Scores1 = maps:put(scores,Scoreboard, Scores),
  sendScores(Sock, Scores1),
  gen_tcp:send(Sock, io_lib:format("MatchOverEnd~n", [])),
  match_manager ! {leaveWaitMatch, Username, self()},
  matchOverUserResponse(Sock, Username).

matchOverUserResponse(Sock, Username) ->
  receive
    {tcp, _, Data} ->
      Info_without_newline = re:replace(Data,"\\n|\\r", "",[global,{return,list}]),
      Info = string:split(Info_without_newline,",",all),
      case Info of
        ["Continue"] ->
          match_manager ! {continue , Username, self()},
          userInGame(Sock, Username, newGame(Sock, Username));
        ["Quit"] ->
          logout(Username),
          %login_manager ! {{logout, Username},self()},
          match_manager ! {leaveWaitMatch, Username, self()},
          userAuth(Sock);
        _ ->
          gen_tcp:send(Sock,io_lib:format("UnknownResponse~n", [])),
          matchOverUserResponse(Sock,Username)
      end;

    {tcp_close, _} ->
      logout(Username),
      match_manager ! {leaveWaitMatch, Username, self()};
      %login_manager ! {{logout, Username},self()};

    {tcp_error, _, _} ->
      logout(Username),
      match_manager ! {leaveWaitMatch, Username, self()}

  end.

initialInfo(Sock, MatchInfo) ->
  gen_tcp:send(Sock, io_lib:format("StartInitialMatchInfo~n", [])),
  sendPlayersInfo(Sock, MatchInfo),
  sendCreaturesInfo(Sock, MatchInfo),
  sendScores(Sock, MatchInfo),
  gen_tcp:send(Sock, io_lib:format("EndInitialMatchInfo~n", [])).

sendUpdateInfo(Sock, UpdateInfo) ->
  gen_tcp:send(Sock, io_lib:format("StartMatchInfo~n", [])),
  sendPlayersInfo(Sock, UpdateInfo),
  sendCreaturesInfo(Sock, UpdateInfo),
  sendScores(Sock, UpdateInfo),
  gen_tcp:send(Sock, io_lib:format("EndMatchInfo~n", [])).

sendPlayersInfo(Sock, MatchInfo) ->
  case maps:find(players, MatchInfo) of
    {ok, Players} ->
      PlayersList = [Player || {_, Player} <- maps:to_list(Players)],
      sendPlayerInfo(Sock, PlayersList);
    error ->
      nothingToSend
  end.

sendPlayerInfo(_, []) ->
  playerDone;
sendPlayerInfo(Sock, [H|T]) ->
  {ok, Username} = maps:find(username, H),
  {ok, X} = maps:find(x, H),
  {ok, Y} = maps:find(y, H),
  {ok, Radius} = maps:find(radius, H),
  {ok, Score} = maps:find(score, H),
  gen_tcp:send(Sock, io_lib:format("P,~s,~w,~w,~w,~w~n", [Username, X, Y, Radius, Score])),
  sendPlayerInfo(Sock, T).

sendCreaturesInfo(Sock, MatchInfo) ->
  case maps:find(creatures, MatchInfo) of
    {ok, Creatures} ->
      sendCreatureInfo(Sock, Creatures, 0);
    error ->
      nothingToSend
  end.

sendCreatureInfo(_, [], _) ->
  creaturesDone;
sendCreatureInfo(Sock, [{Idx, Creature}|T], _) ->
  {ok, Type} = maps:find(type, Creature),
  {ok, X} = maps:find(x, Creature),
  {ok, Y} = maps:find(y, Creature),
  {ok, Radius} = maps:find(radius, Creature),
  gen_tcp:send(Sock, io_lib:format("C,~w,~w,~w,~w,~w~n", [Idx, Type, X, Y, Radius])),
  sendCreatureInfo(Sock, T, ok);
sendCreatureInfo(Sock, [H|T], Idx) ->
  {ok, Type} = maps:find(type, H),
  {ok, X} = maps:find(x, H),
  {ok, Y} = maps:find(y, H),
  {ok, Radius} = maps:find(radius, H),
  gen_tcp:send(Sock, io_lib:format("C,~w,~w,~w,~w,~w~n", [Idx, Type, X, Y, Radius])),
  sendCreatureInfo(Sock, T, Idx+1).

sendScores(Sock, MatchInfo) ->
  case maps:find(scores, MatchInfo) of
    {ok, Scores} ->
      sendScore(Sock, Scores);
    error ->
      nothingToSend
  end.

sendScore(_, []) ->
  scoresDone;
sendScore(Sock, [{Username, Score}|T]) ->
  gen_tcp:send(Sock, io_lib:format("S,~s,~w~n", [Username, Score])),
  sendScore(Sock, T).