import processing.video.*;
import javax.imageio.*;
import java.awt.image.*;
import com.aetrion.flickr.*;

String apiKey = "";
String secretKey = "";
                    
Flickr flickr;
Uploader uploader;
Auth auth;
String frob = "";
String token = "";

Capture cam;
Capture video; 
PImage prevFrame;
float threshold = 50;
int time;
int wait = 1000;
int timeout;

void setup() {
  size(640, 480);
  video = new Capture(this, width, height, 30);
  video.start();
  cam = new Capture(this, 320, 240);  
  cam.start();
  prevFrame = createImage(video.width, video.height, RGB);
  time = millis();
  timeout = 0;
  flickr = new Flickr(apiKey, secretKey, (new Flickr(apiKey)).getTransport());
 
  authenticate();
  uploader = flickr.getUploader();
}

void draw() {
  
  if (video.available()) {
    image(cam, 0, 0);
    prevFrame.copy(video,0,0,video.width,video.height,0,0,video.width,video.height); 
    prevFrame.updatePixels();    
    video.read();
  }
  
  loadPixels();
  video.loadPixels();
  prevFrame.loadPixels();
  int count = 0;
  for (int x = 0; x < video.width; x ++ ) {
    for (int y = 0; y < video.height; y ++ ) {
      
      int loc = x + y*video.width;            
      color current = video.pixels[loc];      
      color previous = prevFrame.pixels[loc]; 
      
      float r1 = red(current); float g1 = green(current); float b1 = blue(current);
      float r2 = red(previous); float g2 = green(previous); float b2 = blue(previous);
      float diff = dist(r1,g1,b1,r2,g2,b2);
      
      if (diff > threshold) { 
        count = count + 1;
        pixels[loc] = color(0);
      } else {
        pixels[loc] = color(255);
      }
    }
  }
  if (count > 35000 && timeout > 200) 
  {
    print("HIT");
    take_picture();
    count = 0;
    timeout = 0;
  }
  updatePixels();  
  timeout = timeout + 1;
  //println(timeout);
}

void take_picture() {
  // Upload the current camera frame.
  println("Uploading");
  
  // First compress it as a jpeg.
  byte[] compressedImage = compressImage(video);
  
  UploadMetaData uploadMetaData = new UploadMetaData(); 
  uploadMetaData.setTitle(hour()+":"+minute()+":"+second()); 
  uploadMetaData.setDescription("Taken on the EECS Haus Photobooth!");   
  uploadMetaData.setPublicFlag(true);

  try {
    uploader.upload(compressedImage, uploadMetaData);
  }
  catch (Exception e) {
    println("Upload failed");
  }
  
  println("Finished uploading");  
}

// Attempts to authenticate. Note this approach is bad form,
// it uses side effects, etc.
void authenticate() {
  // Do we already have a token?
  if (fileExists("token.txt")) {
    token = loadToken();    
    println("Using saved token " + token);
    authenticateWithToken(token);
  }
  else {
   println("No saved token. Opening browser for authentication");    
   getAuthentication();
  }
}

// FLICKR AUTHENTICATION HELPER FUNCTIONS
// Attempts to authneticate with a given token
void authenticateWithToken(String _token) {
  AuthInterface authInterface = flickr.getAuthInterface();  
  
  // make sure the token is legit
  try {
    authInterface.checkToken(_token);
  }
  catch (Exception e) {
    println("Token is bad, getting a new one");
    getAuthentication();
    return;
  }
  
  auth = new Auth();

  RequestContext requestContext = RequestContext.getRequestContext();
  requestContext.setSharedSecret(secretKey);    
  requestContext.setAuth(auth);
  
  auth.setToken(_token);
  auth.setPermission(Permission.WRITE);
  flickr.setAuth(auth);
  println("Authentication success");
}


// Goes online to get user authentication from Flickr.
void getAuthentication() {
  AuthInterface authInterface = flickr.getAuthInterface();
  
  try {
    frob = authInterface.getFrob();
  } 
  catch (Exception e) {
    e.printStackTrace();
  }

  try {
    URL authURL = authInterface.buildAuthenticationUrl(Permission.WRITE, frob);
    
    // open the authentication URL in a browser
    open(authURL.toExternalForm());    
  }
  catch (Exception e) {
    e.printStackTrace();
  }

  println("You have 15 seconds to approve the app!");  
  int startedWaiting = millis();
  int waitDuration = 15 * 1000; // wait 10 seconds  
  while ((millis() - startedWaiting) < waitDuration) {
    // just wait
  }
  println("Done waiting");

  try {
    auth = authInterface.getToken(frob);
    println("Authentication success");
    // This token can be used until the user revokes it.
    token = auth.getToken();
    // save it for future use
    saveToken(token);
  }
  catch (Exception e) {
    e.printStackTrace();
  }
  
  // complete authentication
  authenticateWithToken(token);
}

// Writes the token to a file so we don't have
// to re-authenticate every time we run the app
void saveToken(String _token) {
  String[] toWrite = { _token };
  saveStrings("token.txt", toWrite);  
}

boolean fileExists(String filename) {
  File file = new File(sketchPath(filename));
  return file.exists();
}

// Load the token string from a file
String loadToken() {
  String[] toRead = loadStrings("token.txt");
  return toRead[0];
}

// IMAGE COMPRESSION HELPER FUNCTION

// Takes a PImage and compresses it into a JPEG byte stream
// Adapted from Dan Shiffman's UDP Sender code
byte[] compressImage(PImage img) {
  // We need a buffered image to do the JPG encoding
  BufferedImage bimg = new BufferedImage( img.width,img.height, BufferedImage.TYPE_INT_RGB );

  img.loadPixels();
  bimg.setRGB(0, 0, img.width, img.height, img.pixels, 0, img.width);

  // Need these output streams to get image as bytes for UDP communication
  ByteArrayOutputStream baStream  = new ByteArrayOutputStream();
  BufferedOutputStream bos    = new BufferedOutputStream(baStream);

  // Turn the BufferedImage into a JPG and put it in the BufferedOutputStream
  // Requires try/catch
  try {
    ImageIO.write(bimg, "jpg", bos);
  } 
  catch (IOException e) {
    e.printStackTrace();
  }

  // Get the byte array, which we will send out via UDP!
  return baStream.toByteArray();
}


