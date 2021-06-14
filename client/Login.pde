import static javax.swing.JOptionPane.*;
import javax.swing.JPasswordField;

void login(String username, String password) {
  if (password == null)
    return;

  toSocket.println("login," + username + "," + password);
  toSocket.flush();

  try {
    String answer = fromSocket.readLine();
    loginMenu.set(false);
    messageMenu.set(true);
    if (answer.equals("LoginDone")) {
      message = "Bem-vindo " + username;
      success.set(true);
      onlineMenu.set(true);
    } else if (answer.equals("LoginInvalid")) {
      message = "Login Invalido";
      usrText = "";
      success.set(false);
    } else if (answer.equals("AlreadyLoggedIn")) {
      message = "O utilizador já tem sessão iniciada!";
      usrText = "";
      success.set(false);
    }
  } catch (Exception e) {}

  pwdText = "";
  usr.set(true);
  pwd.set(false);
}

void logout(String username) {
  toSocket.println("logout," + username);
  toSocket.flush();

  try {
    String answer = fromSocket.readLine();
    mainMenu.set(false);
    messageMenu.set(true);
    if (answer.equals("LogoutDone")) {
      message = "Logout feito";
      success.set(true);
      mainMenu.set(true);
    } else if (answer.equals("LogoutInvalid")) {
      message = "Logout Invalido";
      usrText = "";
      success.set(false);
    }
  } catch (Exception e) {}

  pwdText = "";
  usr.set(true);
  pwd.set(false);
}

void create_account(String username, String password) {
    if (password == null)
      return;

    toSocket.println("create_account," + username + "," + password);
    toSocket.flush();

    try {
      String answer = fromSocket.readLine();
      registerMenu.set(false);
      messageMenu.set(true);
      if (answer.equals("Registered")) {
        message = "Bem-vindo "  + username;
        success.set(true);
        //onlineMenu.set(true);
        usrText = "";
        mainMenu.set(true);
      } else if (answer.equals("UserExists")) {
        message = "Já existe um utilizador com esse nome!";
        usrText = "";
        success.set(false);
      }
    } catch (Exception e) {}
  
  pwdText = "";
  usr.set(true);
  pwd.set(false);
}

void close_account(String username, String password) {
    if (password == null)
      return;

    toSocket.println("close_account," + username + "," + password);
    toSocket.flush();

    try {
      String answer = fromSocket.readLine();
      unregisterMenu.set(false);
      messageMenu.set(true);
      if (answer.equals("AccountClosed")) {
        message = "Apagou a conta " + username;
        success.set(true);
        mainMenu.set(true);
      } else if (answer.equals("CloseAccountGoneWrong")) {
        message = "Erro ao fechar conta";
        success.set(false);
        mainMenu.set(true);
      }
    } catch (Exception e) {}
  usrText = "";
  pwdText = "";
  usr.set(true);
  pwd.set(false);
}
