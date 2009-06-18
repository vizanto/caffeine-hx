/*
* Copyright 2008 The MemeDB Contributors (see CONTRIBUTORS)
* Licensed under the Apache License, Version 2.0 (the "License"); you may not
* use this file except in compliance with the License.  You may obtain a copy of
* the License at
*
*   http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
* WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the
* License for the specific language governing permissions and limitations under
* the License.
*/

package memedb.httpd;

import java.io.IOException;

import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import memedb.auth.Credentials;
import memedb.backend.BackendException;
import memedb.document.Document;
import memedb.document.DocumentCreationException;
import memedb.document.JSONDocument;

import memedb.utils.Lock;

import org.json.JSONObject;

/**
 *
 * Handles PUT with no leading _ in db and non-null id<br />
 * Handles POST with no leading _ in db and any id
 * @todo There's still a way to update a document without revision information,
 * when neither _rev in JSON data is specified, or ?rev=. A feature?
 * @author mbreese
 * @author Russell Weir
 */
public class UpdateDocument extends BaseRequestHandler {

	public void handleInner(Credentials credentials, HttpServletRequest request, HttpServletResponse response, String db, String id, String rev) throws IOException, BackendException, DocumentCreationException{
		if(!credentials.canUpdateDocuments(db)) {
			this.sendNotAuth(response);
			return;
		}
		if (!memeDB.getBackend().doesDatabaseExist(db)) {
			sendError(response, "Database does not exist: "+db,HttpServletResponse.SC_NOT_FOUND);
			return;
		}

		int statusCode = HttpServletResponse.SC_CREATED;
		boolean added = false;

		String contentType = request.getContentType();
		if (contentType==null) {
			contentType = Document.DEFAULT_CONTENT_TYPE;
		} else {
			contentType = contentType.split(";")[0];
		}

		Lock lock = null;
		Document newDoc=null;
		Document oldDoc = null;
		String lastRevision = null;
		JSONObject newMetaData = null;

		try {
			if (id!=null) {
				lock = memeDB.getBackend().lockForUpdate(db, id);
				oldDoc = memeDB.getBackend().getDocument(db, id);
				if(oldDoc != null && oldDoc.getContentType() == null)
					oldDoc = null;
			}

			if (oldDoc!=null) {
				if (!oldDoc.getContentType().equals(contentType)) {
					sendError(response,"Mismatch in Content-Type",HttpServletResponse.SC_CONFLICT);
					log.error("Attempted to update a doc of type: {} with one of type: {}",oldDoc.getContentType(),contentType);
					return;
				}
				newDoc = Document.newRevision(
							memeDB.getBackend(),
							oldDoc,
							credentials.getUsername());
				lastRevision = oldDoc.getRevision();
			}

			if (newDoc == null) {
				added = true;
				// if 'id' is null, a new id will be generated by the backend
				newDoc= Document.newDocument(
							memeDB.getBackend(),
							db,
							id,
							contentType,
							credentials.getUsername());
				lastRevision = newDoc.getRevision();
			}

			if(newDoc instanceof JSONDocument) {
				try {
					newMetaData = JSONObject.read(request.getInputStream());
				} catch (IOException e) {
					throw new DocumentCreationException(e);
				}
				if(rev == null)
					rev = newMetaData.optString("_rev", null);
				if(rev == null)
					rev = lastRevision;
			}

			if(rev != null && !rev.equals(lastRevision)) {
				log.warn("Document update conflict id {} rev {} expected {} ", newDoc.getId(), rev, lastRevision);
				sendError(response, "revision_conflict","conflict with last revision: "+ lastRevision,HttpServletResponse.SC_CONFLICT);
				return;
			}
			try {
				if(newMetaData == null)
					newDoc.setRevisionData(request.getInputStream());
				else {
					((JSONDocument) newDoc).setRevisionData(newMetaData);
				}
			} catch(DocumentCreationException e) {
				sendError(response, e.getMessage(), e.getReason(),HttpServletResponse.SC_CONFLICT);
				if(lock != null)
					lock.release();
				return;
			}

			newDoc = memeDB.getBackend().saveDocument(newDoc, lock);
		} finally {
			if(lock != null)
				lock.release();
		}
		sendDocumentOK(response, newDoc.getId(), newDoc.getRevision(), statusCode);
	}

	public boolean match(Credentials credentials, HttpServletRequest request, String db, String id) {
		return (
				db!=null &&
				!db.startsWith("_") &&
				((id!=null && request.getMethod().equals("PUT")) ||
					(/*id==null &&*/ request.getMethod().equals("POST"))) &&
				(!allowHtml || memeDB.getBackend().doesDatabaseExist(db))
				);
	}

}
