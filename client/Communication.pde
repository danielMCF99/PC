class Reader extends Thread {
  BufferedReader b;
  String username;
  int imageID;
  final float scaleX = width/(float)1366;
  final float scaleY = height/(float)768;

  Reader(BufferedReader in, String username, int imID) {
    this.b = in;
    this.username = username;
    this.imageID = imID;
  }

  public void run() {
    while (true) {
      try {
        String info = this.b.readLine();
        if (info.equals("MatchOverBegin")) {
          ArrayList<Score> leaderboard = new ArrayList<Score>();
          info = this.b.readLine();
          while (!info.equals("MatchOverEnd")) {
            String[] fields = info.split(",");
            leaderboard.add(new Score(fields[1], Float.parseFloat(fields[2])));
            info = this.b.readLine();
          }
          GameState e = state.get();
          e.leaderboard = leaderboard;
          state.set(e);
          matchMenu.set(false);
          leaderboardMenu.set(true);
          break;
          
        } else if (info.equals("StartInitialMatchInfo")) {
          GameState e = new GameState();
          e.enemies = new ArrayList<Player>();
          e.creatures = new ArrayList<Creature>();
          e.bestScores = new ArrayList<Score>();
          e.leaderboard = new ArrayList<Score>();
          info = this.b.readLine();
          while (!info.equals("EndInitialMatchInfo")) {
            String[] fields = info.split(",");
            if (fields[0].equals("P")) {
              if (fields[1].equals(this.username))
                // Utilizador da interface
                e.player = new Player(this.username, Float.parseFloat(fields[2]), Float.parseFloat(fields[3]), Float.parseFloat(fields[4]), Float.parseFloat(fields[5]), this.imageID, false);
              else
                // Adversários
                e.enemies.add(new Player(fields[1], Float.parseFloat(fields[2]), Float.parseFloat(fields[3]), Float.parseFloat(fields[4]), Float.parseFloat(fields[5]), this.imageID, true));
            } 
            else if (fields[0].equals("C")) {
              if (fields[2].equals("poison"))
                e.creatures.add(new Creature(Float.parseFloat(fields[3]), Float.parseFloat(fields[4]), Float.parseFloat(fields[5]), 1));
              else if (fields[2].equals("food"))
                e.creatures.add(new Creature(Float.parseFloat(fields[3]), Float.parseFloat(fields[4]), Float.parseFloat(fields[5]), 0));
            }
            else if (fields[0].equals("S")) {
              e.bestScores.add(new Score(fields[1], Float.parseFloat(fields[2])));
            }
            info = this.b.readLine();
          }
          state.set(e);
          waitMatch.set(false);
          matchMenu.set(true);
        } else if (info.equals("StartMatchInfo")) {
          GameState e = state.get();
          ArrayList<Score> scores = new ArrayList<Score>();
          info = this.b.readLine();
          while (!info.equals("EndMatchInfo")) {
            String[] fields = info.split(",");
            if (fields[0].equals("P")) {
              if (fields[1].equals(this.username)) {
                // Utilizador da interface
                e.player.username = this.username;
                e.player.movement(Float.parseFloat(fields[2]), Float.parseFloat(fields[3]));
                e.player.radius = Float.parseFloat(fields[4]);
                e.player.score = Float.parseFloat(fields[5]);
              } else {
                // Adversários
                Player p = null;
                String username = fields[1];
                float x = Float.parseFloat(fields[2]);
                float y = Float.parseFloat(fields[3]);
                float r = Float.parseFloat(fields[4]);
                float score = Float.parseFloat(fields[5]);
                for (int i = 0; i < e.enemies.size(); i++) {
                  p = e.enemies.get(i);
                  if (username.equals(p.username))
                    break;
                }
                if(p != null){
                  p.movement(x, y);
                  p.radius = r;
                  p.setScore(score);
                }
              }
            } else if (fields[0].equals("C")) {
              int type = -1;
              if (fields[2].equals("poison"))
                type = 1;
              else if (fields[2].equals("food"))
                type = 0;
              float x = Float.parseFloat(fields[3]);
              float y = Float.parseFloat(fields[4]);
              float r = Float.parseFloat(fields[5]);
              e.creatures.set(Integer.parseInt(fields[1]), new Creature(x, y, r, type));
            }
            else if (fields[0].equals("S")) {
              scores.add(new Score(fields[1], Float.parseFloat(fields[2])));
            }
            info = this.b.readLine();
          }
          if (scores.size() != 0)
            e.bestScores = scores;
          state.set(e);
        }
      } catch (Exception e) {
        e.printStackTrace();
        break;
      }
    }
  }
}
