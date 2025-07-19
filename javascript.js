var canvas = document.getElementById("canvas");
var ctx = canvas.getContext("2d");
nt=0;
function resizer(){
  w = ctx.canvas.width = window.innerWidth;
  h = ctx.canvas.height = window.innerHeight;
  ctx.filter = "blur(30px)";
}resizer();
window.onresize = () => {resizer()}
function drawWave(n){
  nt+=0.002;
  for(i=0;i<n;i++){
    ctx.beginPath();
    ctx.lineWidth = 30;
    ctx.strokeStyle = "hsla("+(330+(15*i))+",100%,60%,1)";
    for(x=0;x<w;x+=30){
      var y = noise.simplex3(x/800, 0.3*i, nt)*100;
      ctx.lineTo(x,y+(h/2));
    }
    ctx.stroke();
    ctx.closePath();
  }
}
function render(){
  ctx.fillStyle="rgba(0,12,12,1)";
  ctx.fillRect(0,0,w,h);
  drawWave(5);
  requestAnimationFrame(render);
}render();