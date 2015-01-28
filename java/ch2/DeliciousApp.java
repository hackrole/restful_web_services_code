// DeliciousApp.java
import java.io.*;

import org.apache.commons.httpclient.*;
import org.apache.commons.httpclient.auth.AuthScope;
import org.apache.commons.httpclient.methods.GetMethod;

import org.w3c.dom.*;
import org.xml.sax.SAXException;
import javax.xml.parsers.*;
import javax.xml.xpath.*;

/**
 * A command-line application that fetches bookmarks from del.icio.us
 * and prints them to strandard output.
 */
public class DeliciousApp
{
  public static void main(String[] args)
    throws HttpException, IOException, ParserConfigurationException,
           SAXException, XPathExpressionException
  {        
    if (args.length != 2)
    {
      System.out.println("Usage: java -classpath [CLASSPATH] "
                         + "DeliciousApp [USERNAME] [PASSWORD]");
      System.out.println("[CLASSPATH] - Must contain commons-codec, " +
                         "commons-logging, and commons-httpclient");
      System.out.println("[USERNAME]  - Your del.icio.us username");
      System.out.println("[PASSWORD]  - Your del.icio.us password");
      System.out.println();

      System.exit(-1);
    }

    // Set the authentication credentials.
    Credentials creds = new UsernamePasswordCredentials(args[0], args[1]);
    HttpClient client = new HttpClient();
    client.getState().setCredentials(AuthScope.ANY, creds);

    // Make the HTTP request.
    String url = "https://api.del.icio.us/v1/posts/recent";
    GetMethod method = new GetMethod(url);
    client.executeMethod(method);
    InputStream responseBody = method.getResponseBodyAsStream();

    // Turn the response entity-body into an XML document.
    DocumentBuilderFactory docBuilderFactory =
      DocumentBuilderFactory.newInstance();
    DocumentBuilder docBuilder = 
      docBuilderFactory.newDocumentBuilder();
    Document doc = docBuilder.parse(responseBody);
    method.releaseConnection();

    // Hit the XML document with an XPath expression to get the list
    // of bookmarks.
    XPath xpath = XPathFactory.newInstance().newXPath();        
    NodeList bookmarks = (NodeList)xpath.evaluate("/posts/post", doc,
                                                  XPathConstants.NODESET);

    // Iterate over the bookmarks and print out each one.
    for (int i = 0; i < bookmarks.getLength(); i++)
    {
       NamedNodeMap bookmark = bookmarks.item(i).getAttributes();
       String description = bookmark.getNamedItem("description")
           .getNodeValue();
       String uri = bookmark.getNamedItem("href").getNodeValue();
       System.out.println(description + ": " + uri);
    }

    System.exit(0);
  }
}
