import java.net.Socket;
import java.io.OutputStream;
import java.io.InputStream;
import java.io.IOException;

public class CheckURL {
public static void main(String args[]) {
   String host;
   String file;
   String port;
   
   if (args.length <1) {
      System.out.println("Usage:   java CheckURL <URL without protocol name> <http port default 80>");
      System.out.println("Example: www.google.com/index.html 80");
      System.exit(1);
   }
   
   if (args.length ==2) {
      // there's port parse it
      port = args[1];
   }
   else {
      port = new String("80");
   }
   
   
   int delimIndex = args[0].indexOf('/');
   if (delimIndex == -1) {
      // there's no "/" in the URL
      // assume only the host name is given
      // requesting "/" as a file
      host = args[0];
      file = new String("/");
   }
   else {
      // split host and filename
      host = args[0].substring(0, delimIndex);
      file = args[0].substring(delimIndex);
   }
   
   try {
      // create connection to port
      Socket socket = new Socket(host, Integer.parseInt(port));
      // obtain socket's output stream
      OutputStream out = socket.getOutputStream();
      // Assemble command
      String command = new String("GET " + file + " HTTP/1.0\r\n\r\n");
      // Write HTTP GET command
      out.write(command.getBytes());
      // Ensure that the command is really sent
      // and doesn't get left in the temp buffer
      out.flush();
      // Obtain socket's input stream
      InputStream in = socket.getInputStream();
      int aByte;
      // read from the input stream until end
      // during read write every char to STO
      while ((aByte = in.read()) != -1) {
         System.out.write(aByte);
      }
      // realease resources
      out.close();
      in.close();
      socket.close();
   }
   // if errors occured write them
   // to STO
   catch (IOException ioe) {
      System.out.println(ioe.toString());
      System.exit(1);
   }
}
} //end of the class
