class Creature{
  
  PVector position;
  float radius;
  int type; // 0 -> comestivel; 1 -> venenosa
 
  Creature(){
    this.position = new PVector(0,0);
    this.radius = 0;
    this.type = 0;
  }  
  
  Creature(float x, float y, float r, int t){
    this.position = new PVector(x,y);
    this.radius = r;
    this.type = t;
  }
  
  Creature(Creature c){
    this.position = c.getPosition();
    this.radius = c.getRadius();
    this.type = c.getType();
  }
  
  PVector getPosition(){
    return this.position.copy();
  }
  
  float getRadius(){
    return this.radius;
  }
  
  int getType(){
    return this.type;
  }
  
  void showCreature(){
    if(this.type == 0){
      fill(0,255,0);
      ellipse(this.position.x, this.position.y, radius, radius);
    }else if(this.type == 1){
      fill(255,0,0);
      ellipse(this.position.x, this.position.y, radius, radius);
    }
    strokeWeight(1); //grossura da linha para desenho
    stroke(0); //cor usada para desenhar linhas à volta de figuras
  }
  
  Creature clone(){
    return new Creature(this);
  }  
}
