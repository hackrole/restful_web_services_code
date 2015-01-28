/*
 * Copyright 2005-2007 Noelios Consulting.
 * 
 * The contents of this file are subject to the terms of the Common Development
 * and Distribution License (the "License"). You may not use this file except in
 * compliance with the License.
 * 
 * You can obtain a copy of the license at
 * http://www.opensource.org/licenses/cddl1.txt See the License for the specific
 * language governing permissions and limitations under the License.
 * 
 * When distributing Covered Code, include this CDDL HEADER in each file and
 * include the License file at http://www.opensource.org/licenses/cddl1.txt If
 * applicable, add the following below this CDDL HEADER, with the fields
 * enclosed by brackets "[]" replaced with your own identifying information:
 * Portions Copyright [yyyy] [name of copyright owner]
 */

package org.restlet.example.book.rest.ch2;

import org.restlet.Client;
import org.restlet.data.ChallengeResponse;
import org.restlet.data.ChallengeScheme;
import org.restlet.data.Method;
import org.restlet.data.Protocol;
import org.restlet.data.Request;
import org.restlet.data.Response;
import org.restlet.resource.DomRepresentation;
import org.w3c.dom.NamedNodeMap;
import org.w3c.dom.Node;

/**
 * Getting your list of recent bookmarks on del.icio.us.
 * 
 * @author Jerome Louvel (contact@noelios.com)
 */
public class Example2_5 {
    public static void main(String[] args) throws Exception {
        if (args.length != 2) {
            System.err
                    .println("You need to pass your del.icio.us user name and password");
        } else {
            // Create a authenticated request
            Request request = new Request(Method.GET,
                    "https://api.del.icio.us/v1/posts/recent");
            request.setChallengeResponse(new ChallengeResponse(
                    ChallengeScheme.HTTP_BASIC, args[0], args[1]));

            // Fetch a resource: an XML document with your recent posts
            Response response = new Client(Protocol.HTTPS).handle(request);
            DomRepresentation document = response.getEntityAsDom();

            // Use XPath to find the interesting parts of the data structure
            for (Node node : document.getNodes("/posts/post")) {
                NamedNodeMap attrs = node.getAttributes();
                String desc = attrs.getNamedItem("description").getNodeValue();
                String href = attrs.getNamedItem("href").getNodeValue();
                System.out.println(desc + ": " + href);
            }
        }
    }
}
