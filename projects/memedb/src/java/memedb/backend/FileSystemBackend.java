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

package memedb.backend;

import java.io.EOFException;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.FileWriter;
import java.io.IOException;
import java.io.OutputStream;
import java.io.RandomAccessFile;
import java.io.Writer;
// import java.io.UnsupportedEncodingException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Iterator;
import java.util.List;
import java.util.Map;
import java.util.Set;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import memedb.MemeDB;
import memedb.document.Document;
import memedb.document.DocumentCreationException;
import memedb.utils.FileUtils;
import memedb.utils.LineCallback;
import memedb.utils.Lock;
import memedb.utils.Logger;

/**
 * Stores documents as files / directories. All of the information is stored
 *
 * The file structure is: / db / doc id / _revisions - list of revisions in
 * order - one line per revision, most recent is last / _common - common data
 * for all revisions (created date, current revision, etc... ) in JSON format /
 * _permissions - the permissions for this document / rev_id - a file for each
 * revision in JSON format
 *
 * @author mbreese
 * @author Russell Weir
 *
 */
public class FileSystemBackend implements Backend {

	private class DBStats {
		private String name;
		private File path;
		private long createSequenceNumber = -1;
		private long documentCount = -1;
		private RandomAccessFile fp;
		
		public DBStats(String dbName, File path) {
			this.name = dbName;
			this.path = new File(path, dbName + ".dat");
		}
		
		public void create(long seqNo) throws IOException {
			if(path.exists()) {
				path.delete();
			}
			this.createSequenceNumber = seqNo;
			this.documentCount = 0;
			fp = new RandomAccessFile(path, "rws");
			save();
		}
		
		public void destroy() {
			try {
				fp.close();
			} catch(Exception e) {}
			try {
				path.delete();
			} catch(Exception e) {}
		}

		public long getDocumentCount() {
			return documentCount;
		}
		
		public long getCreateSequenceNumber() {
			return this.createSequenceNumber;
		}
		
		public void init() throws IOException {
			fp = new RandomAccessFile(path, "rws");
			createSequenceNumber = fp.readLong();
			documentCount = fp.readLong();			
		}
		
		public void onDocumentCreated() throws IOException {
			synchronized(fp) {
				documentCount++;
				fp.seek(8);
				fp.writeLong(documentCount);
			}		
		}
		
		public void onDocumentDeleted() throws IOException {
			synchronized(fp) {
				documentCount--;
				fp.seek(8);
				fp.writeLong(documentCount);
			}
		}
		
		private void save() throws IOException {
			fp.seek(0);
			fp.writeLong(this.createSequenceNumber);
			fp.writeLong(documentCount);
		}
				
		public void setDocumentCount(long v) throws IOException {
			synchronized(fp) {
				documentCount = v;
				fp.seek(8);
				fp.writeLong(documentCount);
			}			
		}
		
		public void shutdown() {
			try {
				fp.close();
			} catch(Exception e) {}
		}
	}
	
	public static final String BACKEND_SUBDIR_COUNT = "backend.fs.depth";
	public static final String BACKEND_FS_PATH = "backend.fs.path";
	public static final String BACKEND_STATE_PATH = "backend.fs.statedir";
	public static final int defaultSubdirCount = 5;

	private MemeDB memeDB;
	private File rootDir;
	private int subDirCount;
	private HashMap<String,DBStats> stats = new HashMap<String,DBStats>();

	final private Logger log = Logger.get(FileSystemBackend.class);


	public FileSystemBackend() {
	}

	private final File dbDir(String db) {
		return new File(rootDir, db);
	}

	private String subDir(String idEnc) {
		int max = idEnc.length() > subDirCount ? subDirCount : idEnc.length() - 1;
		if(max < 0) max = idEnc.length() - 1;
		if(max == 0) return idEnc;
		StringBuffer sb = new StringBuffer(idEnc.length() * 2 + 1 );
		for (int i = 0; i < max; i++) {
			if(i != 0)
				sb.append('/');
	    	sb.append(idEnc.charAt(i));
		}
		if(sb.length() > 0)
			sb.append('/');
		sb.append(idEnc);
		return sb.toString();
	}

	private File docDir(String db, String id) {
		return new File(dbDir(db), subDir(FileUtils.fsEncode(id)));
	}

	public void deleteDocument(String db, String id) throws BackendException {
		File docDir = docDir(db, id);
		if (!docDir.exists()) {
			log.warn("Deleting non-existant document {}/{}", db,id);
			return;
		}
		log.debug("Deleting document {}/{}", db, id);
		memeDB.getState().deleteDocument(db, id);
		deleteRecursive(docDir);
		try {
			stats.get(db).onDocumentDeleted();
		} catch(Exception e) {
			throw new BackendException("Error updating db stats : " + e.getMessage(), e);
		}
	}

	public void shutdown() {
		for (DBStats s: stats.values()) {
			s.shutdown();
		}
	}

	public Iterable<Document> allDocuments(final String db) {
		return getDocuments(db, null);
	}
	
	protected void findAllDocuments(List<String> ids, File baseDir, String baseName) {
		for (File f: baseDir.listFiles()) {
			if (f.isDirectory()) {
				if (new File(f,"_common").exists()) {
					log.debug("found _common file in {}",f.getAbsolutePath());
					String realId = FileUtils.fsDecode(f.getName());
					log.debug("adding id: {}", realId);
					ids.add(realId);
				} else {
					if (baseName!=null) {
						findAllDocuments(ids,f,baseName+"/"+f.getName());
					} else {
						findAllDocuments(ids,f,f.getName());
					}
				}
			}
		}
	}

	public MemeDB getMeme() {
		return memeDB;
	}

	public Iterable<Document> getDocuments(final String db, final String[] ids) {
		File dbDir = dbDir(db);

		final String[] idList;

		if (ids == null) {
			List<String> existingIds = new ArrayList<String>();
			findAllDocuments(existingIds,dbDir,null);
			idList = new String[existingIds.size()];
			int i=0;
			for (String id:existingIds) {
// 				log.debug("found doc id => {}",id);
				idList[i++] = id;
			}
		} else {
			idList = ids;
		}
		final Iterator<Document> i = new Iterator<Document>() {
			int index = 0;

			Document nextDoc = null;

			public void findNext() {
				nextDoc = null;
				while (idList != null && index < idList.length && nextDoc == null) {
					nextDoc = getDocument(db,idList[index]);
					index++;
				}
			}

			public boolean hasNext() {
				if (index == 0 && nextDoc == null) {
					findNext();
				}
				return nextDoc != null;
			}

			public Document next() {
				Document nd = nextDoc;
				findNext();
				return nd;
			}

			public void remove() {
				findNext();
			}

		};
		return new Iterable<Document>() {
			public Iterator<Document> iterator() {
				return i;
			}
		};
	}

	public Long getDatabaseCreationSequenceNumber(String db) {
		try {
			return stats.get(db).getCreateSequenceNumber();
		} catch(Exception e) {
		}
		return null;
	}
	
	public Set<String> getDatabaseNames() {
		Set<String> dbs = new HashSet<String>();

		for (File f : rootDir.listFiles()) {
			if (f.isDirectory()) {
				dbs.add(f.getName());
			}
		}
		return dbs;
	}

	public Document getDocument(String db, String id) {
		return getDocument(db, id, null);
	}

	public Document getDocument(String db, String id, String rev) {
		File docDir = docDir(db, id);
		log.debug("Retrieving document {}/{}/{}", db, id, rev);

		try {
			File commonFile = new File(docDir, "_common");

			if (!commonFile.exists()) {
				log.debug("Document _common file not found: {}/{} in {}",db,id,docDir.toString());
				return null;
			}

			JSONObject commonJSON = JSONObject.read(new FileInputStream(commonFile));

			if(commonJSON.length() == 0)
				return null;
			
			if (rev == null) {
				rev = commonJSON.getString(Document.CURRENT_REVISION);
			}


			File metaFile = new File(docDir, rev+".meta");
			if (!metaFile.exists()) {
				log.warn("Document .meta file not found: {}/{}/{}",db,id,rev);
				return null;
			}

			JSONObject metaJSON = JSONObject.read(new FileInputStream(metaFile));

			Document d =  Document.loadDocument(this, commonJSON, metaJSON);
			if (d.writesRevisionData()) {
				// this doesn't apply to JSON docs
				File revFile = null;
				if(d.requiresRevisionExtension())
					revFile = new File(docDir, rev + "." + d.getRevisionExtension());
				else
					revFile = new File(docDir, rev);
				if (!revFile.exists()) {
					log.warn("Document revision file not found: {}/{}/{}",db,id,rev);
					return null;
				}
				d.setRevisionData(new FileInputStream(revFile));
			}
			return d;
		} catch (JSONException e) {
			e.printStackTrace();
		} catch (IOException e) {
			e.printStackTrace();
		} catch (DocumentCreationException e) {
			e.printStackTrace();
		}
		return null;
	}

	public Long getDocumentCount(String db) {
		try {
			return stats.get(db).getDocumentCount();
		} catch(Exception e) {
		}
		return null;
	}
	
	public File getRevisionFilePath(Document d) throws BackendException {
		if(!d.writesRevisionData())
			throw new BackendException("Does not write revision data");

		if(d.requiresRevisionExtension())
			return new File(docDir(d.getDatabase(), d.getId()), d.getRevision()+ "." + d.getRevisionExtension());
		else
			return new File(docDir(d.getDatabase(), d.getId()), d.getRevision());

	}

	public long addDatabase(String name) throws BackendException {
		File dir = dbDir(name);
		if (dir.exists()) {
			log.error("Database dir '{}' already exists!",name);
			throw new BackendException("The database " + name
					+ " already exists");
		}
		log.debug("Adding database: {}",name);
		dir.mkdir();

		long rv = 0;
		try {
			DBStats s = new DBStats(name, rootDir);
			stats.put(name, s);
			rv = memeDB.getState().addDatabase(name);
			s.create(rv);
		} catch(Exception e) {
			dir.delete();
			stats.remove(name);
			throw new BackendException("Error creating database info file: " + e.getMessage());
		}
		return rv;
	}

	public long deleteDatabase(String name) throws BackendException {
		File dir = dbDir(name);
		long rv = 0;
		if (dir.exists() && dir.isDirectory()) {
			rv = memeDB.getState().deleteDatabase(name);
			deleteRecursive(dir);
			DBStats s = stats.get(name);
			if(s != null) {
				s.destroy();
			}
			stats.remove(name);
		}
		return rv;
	}

	private void deleteRecursive(File dir) {
		if (dir.isDirectory()) {
			for (File child : dir.listFiles()) {
				if (child.isDirectory()) {
					deleteRecursive(child);
				}
				child.delete();
			}
		}
		if (dir.exists()) {
			dir.delete();
		}
	}

	public boolean doesDatabaseExist(String db) {
		return dbDir(db).exists();
	}

	public boolean doesDocumentExist(String db, String id) {
		return docDir(db, id).exists();
	}

	public boolean doesDocumentRevisionExist(String db, String id,
			String revision) {
		return new File(docDir(db, id), revision).exists();
	}

	public Lock lockForUpdate(String db, String id) throws BackendException {
		if(!doesDatabaseExist(db)) {
			throw new BackendException("database "+ db +" does not exist");
		}
		File docDir = docDir(db, id);

		if (!docDir.exists()) {
			log.info("Creating document dir: {}",docDir(db,id));
			docDir.mkdirs();
			try {
				File commonFile = new File(docDir, "_common");  // for common
																// data elements
				commonFile.createNewFile();
				FileUtils.writeToFile(commonFile, "{}");


				new File(docDir, "_revisions").createNewFile(); // for keeping
																// revisions in
																// order
				DBStats s = stats.get(db);
				s.onDocumentCreated();
			} catch (IOException e) {
				throw new BackendException(e);
			}
		}
		return Lock.lock(docDir);
	}

	public Document saveDocument(Document doc) throws BackendException {
		Lock lock = lockForUpdate(doc.getDatabase(), doc.getId());
		try {
			saveDocument(doc, lock);
		} finally {
			lock.release();
		}
		return doc;
	}

	public Document saveDocument(Document doc, Lock lock) throws BackendException
	{
		boolean hasExternalLock = lock != null;
		if(!hasExternalLock)
			lock = lockForUpdate(doc.getDatabase(), doc.getId());

		JSONObject commonJSON = doc.getCommonData();
		commonJSON.put(Document.CURRENT_REVISION, doc.getRevision());
		File docDir = docDir(doc.getDatabase(), doc.getId());
		boolean reindex = false;

		// update the sequence number for the document
		if (doc.isCommonDirty() || doc.isDataDirty()) {
			memeDB.getState().updateDocument(doc);
			reindex = true;
		}

		// write out all revision'd elements
		if (doc.isDataDirty()) {
			log.info("updating revision file : {} #{}",doc.getId(),doc.getRevision());
			try {
				File revisionMetaFile = new File(docDir, doc.getRevision()+".meta");

				// add the current revision to the _revisions file (if needed)
				if (!revisionMetaFile.exists() || revisionMetaFile.length() == 0) {
					File revListFile = new File(docDir, "_revisions");
					FileUtils.writeToFile(revListFile, doc.getRevision() + "\n", true);

					// write the document's revision data if req'd
					if (doc.writesRevisionData()) {
						File revFile = null;
						if(doc.requiresRevisionExtension())
							revFile = new File(docDir, doc.getRevision() + "." + doc.getRevisionExtension());
						else
							revFile = new File(docDir, doc.getRevision());
						OutputStream out = new FileOutputStream(revFile);
						doc.writeRevisionData(out);
						out.close();
					}

					// write the meta json data
					Writer metaWriter = new FileWriter(revisionMetaFile);
					doc.getMetaData().write(metaWriter);
					metaWriter.close();
				}
			} catch (IOException e) {
				if(!hasExternalLock)
					lock.release();
				throw new BackendException(e);
			}
		}

		// write out all common elements ( if the data is dirty, there is a new current_rev, so a new common
		// needs to be written
		if (doc.isCommonDirty() || doc.isDataDirty()) {
			log.info("updating common file : {}",doc.getId());
			try {
				File commonFile = new File(docDir, "_common");
				//System.err.println("Writing common: "+commonJSON.toString(2));
				Writer writer = new FileWriter(commonFile);
				commonJSON.write(writer);
				writer.close();
			} catch (IOException e) {
				if(!hasExternalLock)
					lock.release();
				throw new BackendException(e);
			}
		}
		if(!hasExternalLock)
			lock.release();
		if(reindex)
			memeDB.getState().finalizeDocument(doc);
		return doc;
	}

	public JSONArray getDocumentRevisions(String db, final String id) {
		final JSONArray ar = new JSONArray();

		File docDir = docDir(db, id);
		File revListFile = new File(docDir, "_revisions");

		try {
			FileUtils.readFileByLine(revListFile,new LineCallback() {
				public void process(String line) {
					ar.put(line.trim());
				}
			});
		} catch (IOException e) {
			// I don't like silent exceptions...
			log.error("Error loading revisions for {}/{}",db,id);
		}

		return ar;
	}

	public Map<String, Object> getDatabaseStats(String name) {
		Map<String, Object> m = new HashMap<String, Object>();
		if(!this.doesDatabaseExist(name))
			return m;
		m.put("db_name", name);
		DBStats s= stats.get(name);
		if(s != null)
			m.put("doc_count", s.getDocumentCount());
		else
			m.put("doc_count", 0);
		return m;
	}

	public void init(MemeDB memeDB) {
		this.memeDB=memeDB;
		String path = memeDB.getProperty(BACKEND_FS_PATH);
		if (path == null) {
			throw new RuntimeException(
					"You must include a "+BACKEND_FS_PATH+" element in memedb.properties or specify a backend in the MemeDB constructor.");
		}
		log.info("Using database path {}", path);
		this.rootDir = new File(path);
		if (!rootDir.exists()) {
			log.debug("Creating database directory");
			rootDir.mkdirs();
		} else if (!rootDir.isDirectory()) {
			log.error("Path: {} not valid!", path);
			throw new RuntimeException("Path: " + path + " not valid!");
		}

		// Set the number of characters deep that directories
		// will be nested for saving documents.
		this.subDirCount = defaultSubdirCount;
		if (memeDB.getProperty(BACKEND_SUBDIR_COUNT)!=null) {
			try {
				this.subDirCount=Integer.parseInt(memeDB.getProperty(BACKEND_SUBDIR_COUNT));
			} catch (NumberFormatException e) {
				throw new RuntimeException("Error in "+BACKEND_SUBDIR_COUNT+" setting",e);
			}
		}
		
		try {
			for(File f: rootDir.listFiles()) {
				if(f.isDirectory()) {
					String name = FileUtils.fsDecode(f.getName());
					DBStats s = new DBStats(name,rootDir);
					s.init();
					stats.put(name, s);
					if(s.getDocumentCount() < 0) {
						log.warn("Recreating document count for {}", name);
						s.setDocumentCount(this.countFiles(dbDir(name), name));
					}
				}
			}
		} catch(Exception e) {
			throw new RuntimeException(e);
		}
	}


	/**
	 * This makes a place-holder file to avoid revision name duplicates.
	 * @return true if the revision does not exist and was successfully created; false if the named revision already exists
	 */
	public boolean touchRevision(String db, String id, String rev) {
		try {
			docDir(db, id).mkdirs();
			return new File(docDir(db, id), rev + ".meta").createNewFile();
		} catch (IOException e) {
			e.printStackTrace();
			return false;
		}
	}

	private long countFiles(File baseDir, String baseName) {
		long count = 0;
		for (File f: baseDir.listFiles()) {
			if (f.isDirectory()) {
				if (new File(f,"_common").exists()) {
					count++;
				} else {
					if (baseName!=null) {
						count += countFiles(f,baseName+"/"+f.getName());
					} else {
						count += countFiles(f,f.getName());
					}
				}
			}
		}
		return count;
	}
}
