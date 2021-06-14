import java.lang.Comparable;

class Player implements Comparable{
  PVector position;
  float radius;
  String username;
  float score;
  int imageID;
  boolean enemy;
  
  Player(){
    this.position = new PVector(0,0);
    this.radius = 0;
    this.username = "";
    this.score = 0;
    this.imageID = 0;
    this.enemy = false;
  }
  
  Player(String un, float x, float y, float r, float s, int imID, boolean en){
    this.position = new PVector(x,y);
    this.radius = r;
    this.username = un;
    this.score = s;
    this.imageID = imID;
    this.enemy = en;
  }
  
  Player(Player p){
    this.position = new PVector(p.getPosition().x , p.getPosition().y);
    this.radius = p.getRadius();
    this.username = p.getUsername();
    this.score = p.getScore();
    this.imageID = p.getImageID();
    this.enemy = p.getEnemy();
  }
  
  PVector getPosition(){
    return this.position.copy();
  }
  
  float getRadius(){
    return this.radius;
  }
  
  synchronized int getImageID() {
    return this.imageID;
  }

  synchronized void setImageID(int imID) {
    this.imageID = imID;
  }

  String getUsername() {
    return this.username;
  }
  
  synchronized float getScore(){
    return this.score;
  }
  
  synchronized void setScore(float s){
    this.score = s;
  }

  boolean getEnemy() {
    return this.enemy;
  }
  
  synchronized void movement(float newx, float newy){
    this.position = new PVector(newx, newy);
  }
  
  int compareTo(Object object) {
    if(object == null)
      return 0;
    Player p = (Player)object;
    if (this.radius > p.radius)
      return 1;
    else
      return -1;
  }

  void showIcons() {
    PShape sh = icons.get(this.imageID);
    fill(255, 0);

    shape(sh, position.x, position.y, radius*2, radius*2);
    ellipse(position.x, position.y, radius*2, radius*2);

    textSize(this.radius/3);
    if (this.enemy)
      fill(255, 0, 0);
    else
      fill(0, 0, 255);
    textAlign(CENTER, CENTER);
    text(this.getScore(), position.x, position.y);
  }
  
  void showNormal() {
    fill(0);
    ellipse(position.x, position.y, radius*2, radius*2);
    
    // Borda ondulada
    float smoothness = 0.1; // Quanto menor é este valor, mais suave é a borda
    int maxOffset = 4; // Número de píxeis máximo que a borda se vai afastar da circunferência
    noFill();
    beginShape();
    for(int i = 0; i < 360; i++){
      float x = this.position.x + this.radius*cos(TWO_PI*i/360);
      float y = this.position.y + this.radius*sin(TWO_PI*i/360);
      float n = map(noise(smoothness*(frameCount+x), smoothness*(frameCount+y), 0), 0, 1, -maxOffset, maxOffset);
      x += n;
      y += n;
      vertex(x, y);
    }
    endShape();

    textSize(this.radius/3);
    fill(255);
    textAlign(CENTER, CENTER);
    text(this.getScore(), position.x, position.y);
  }
  
  void show() {
    strokeWeight(4);
    if (this.enemy)
      stroke(255, 0, 0);
    else
      stroke(0, 0, 255);

    if(iconsOn.get())
      showIcons();
    else
      showNormal();

    fill(0);
    if (!this.enemy) {
      fill(0, 0, 255);
    }
    textSize(18);
    textAlign(CENTER,TOP);
    text(this.username, position.x, (position.y - this.radius) - 25);
    strokeWeight(1);
    stroke(0);
    fill(0);
  }

  Player clone() {
    return new Player(this);
  }
  
  String toString(){
    return this.username;
  }
  
}
