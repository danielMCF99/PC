-module(login_manager).
-export([start_login/0, create_account/2, close_account/2, login/2, logout/1, online/0, stop/0]).

start_login() ->
    spawn(fun() -> loop(maps:new())  end).

call(Request) ->
    login_manager ! {Request, self()},
    receive {Res, login_manager} -> Res end.

create_account(User, Pass) -> call({create_account, User, Pass}).
close_account(User, Pass) -> call({close_account, User, Pass}).
login(User, Pass) -> call({login, User, Pass}).
logout(User) -> call({logout, User}).
online() -> call(online).
stop() -> call(stop).

loop(Map) ->
    receive
    %From é o pid de quem enviou o pedido

        {{create_account, User, Pass}, From} ->
            % verificar se este pid já está no dicionário ou não
            case maps:find(User, Map) of
                error ->
                    % enviar a mensagem a quem fez o pedido(FROm)
                    From ! {account_created, login_manager},
                    % criar a conta, adicionando ao dict o username e um tuplo passwd e logged in
                    loop(maps:put(User, {Pass, false}, Map));

                % como já existe, envia a quem pediu a mensagem a dizer que existe
                _ ->
                    From ! {user_exists, login_manager},
                    loop(Map)
            end;

        {{close_account, User, Pass}, From} ->
            case maps:find(User, Map) of
                % usa o pattern matching se a Pass no argumento for igual ao que está no dict, senão dá erro
                {ok, {Pass, _}} ->
                    From ! {account_closed, login_manager},
                    loop(maps:remove(User, Map));

                _ ->
                    From ! {user_not_exists, login_manager},
                    loop(Map)
            end;

        {{login, User, Pass}, From} ->
            case maps:find(User, Map) of
                {ok, {Pass, false}} ->
                    From ! {login_done, login_manager},
                    loop(maps:put(User, {Pass, true}, Map));
                {ok, {Pass, true}} ->
                    From ! {already_logged_in, login_manager},
                    loop(Map);
                _ ->
                    From ! {login_invalid, login_manager},
                    loop(Map)
            end;

        {{logout, User}, From} ->
            case maps:find(User, Map) of
                {ok, {Pass, _}} ->
                    From ! {logout_done, login_manager},
                    loop(maps:put(User, {Pass, false}, Map));
                _ ->
                    From ! {logout_invalid, login_manager},
                    loop(Map)
            end;

        {online, From} ->
            User_list = [User || {User, {_, true}} <- maps:to_list(Map)],
            From ! {{online, User_list},login_manager},
            loop(Map);

        {stop, From} ->
            From ! {stopped, login_manager}

    end.