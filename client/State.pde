class GameState {
  Player player;
  ArrayList<Player> enemies;
  ArrayList<Creature> creatures;
  ArrayList<Score> bestScores;
  ArrayList<Score> leaderboard;

  GameState() {
    this.player = new Player();
    this.enemies = new ArrayList<Player>();
    this.creatures = new ArrayList<Creature>();
    this.bestScores = new ArrayList<Score>();
    this.leaderboard = new ArrayList<Score>();
  }

  synchronized GameState get() {
    GameState res = new GameState();
    res.player = this.player.clone();
    
    ArrayList<Player> players = new ArrayList<Player>();
    for(Player p: this.enemies) {
      players.add(p.clone());
    }
    res.enemies = players;

    ArrayList<Creature> creatures = new ArrayList<Creature>();
    for(Creature c: this.creatures) {
      creatures.add(c.clone());
    }
    res.creatures = creatures;

    ArrayList<Score> bestScores = new ArrayList<Score>();
    for(Score s: this.bestScores) {
      bestScores.add(s);
    }
    res.bestScores = bestScores;

    ArrayList<Score> leaderboard = new ArrayList<Score>();
    for(Score s: this.leaderboard) {
      leaderboard.add(s);
    }
    res.leaderboard = leaderboard;
    return res;
  }

  synchronized void set(GameState e) {
    this.player = new Player(e.player);

    this.enemies = new ArrayList<Player>();
    for(Player p: e.enemies) {
      this.enemies.add(p.clone());
    }
    
    this.creatures = new ArrayList<Creature>();
    for(Creature c: e.creatures) {
      this.creatures.add(c.clone());
    }

    this.bestScores = new ArrayList<Score>();
    for(Score s: e.bestScores) {
      this.bestScores.add(s);
    }

    this.leaderboard = new ArrayList<Score>();
    for(Score s: e.leaderboard) {
      this.leaderboard.add(s);
    }

  }
}

class Score {
  String username;
  float score;

  Score(String username, float score) {
    this.username = username;
    this.score = score;
  }
}
