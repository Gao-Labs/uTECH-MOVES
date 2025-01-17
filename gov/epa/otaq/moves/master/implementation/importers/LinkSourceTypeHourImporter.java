/**************************************************************************************************
 * @(#)LinkSourceTypeHourImporter.java 
 *
 *************************************************************************************************/
package gov.epa.otaq.moves.master.implementation.importers;

import gov.epa.otaq.moves.master.framework.importers.*;
import gov.epa.otaq.moves.common.*;

import java.io.*;
import java.sql.*;
import javax.xml.parsers.*;
import org.xml.sax.*;
import org.xml.sax.helpers.*;
import org.w3c.dom.*;
import gov.epa.otaq.moves.master.runspec.*;
import gov.epa.otaq.moves.master.gui.RunSpecSectionStatus;
import gov.epa.otaq.moves.common.*;

/**
 * MOVES LinkSourceTypeHour Importer.  Imports data in MOVES format (as opposed to
 * NMIM or Mobile format) into MOVES.
 * 
 * @author		Wesley Faler
 * @version		2015-09-16
**/
public class LinkSourceTypeHourImporter extends ImporterBase {
	/** Data handler for this importer **/
	BasicDataHandler basicDataHandler;
	/** Part object **/
	TableFileLinkagePart part;

	/**
	 * Name of the primary table handled by the importer.
	 * Note the MOVES database naming convention.
	**/
	String primaryTableName = "linkSourceTypeHour";

	/**
	 * Descriptor of the table(s) imported, exported, and cleared by this importer.
	 * The format is compatible with BasicDataHandler.
	**/
	static String[] dataTableDescriptor = {
		BasicDataHandler.BEGIN_TABLE, "LinkSourceTypeHour",
		"linkID", "", "",
		"sourceTypeID", "SourceUseType", ImporterManager.FILTER_SOURCE,
		"sourceTypeHourFraction", "", ImporterManager.FILTER_NON_NEGATIVE
	};

	/** Class for editing the data source **/
	class PartProvider implements TableFileLinkagePart.IProvider {
		/**
		 * Get the name of the table being managed
		 * @return the name of the table being managed
		**/
		public String getTableName() {
			return primaryTableName;
		}

		/**
		 * Create a template file (or files).
		 * @param destinationFile file selected by the user to be created.  The file may already
		 * exist.
		 * @return true if the template was created successfully, false otherwise.
		**/
		public boolean createTemplate(File destinationFile) {
			return dataHandler.createTemplate(getTableName(),destinationFile);
		}
	}

	/** Class for interfacing to BasicDataHandler's needs during an import **/
	class BasicDataHandlerProvider implements BasicDataHandler.IProvider {
		/**
		 * Obtain the name of the file holding data for a table.
		 * @param tableName table in question
		 * @return the name of the file holding data for a table, null or blank if
		 * no file has been specified.
		**/
		public String getTableFileSource(String tableName) {
			if(tableName.equalsIgnoreCase(primaryTableName)) {
				return part.fileName;
			}
			return null;
		}

		/**
		 * Obtain the name of the worksheet within an XLS file holding data for a table.
		 * @param tableName table in question
		 * @return the name of the worksheet within an XLS file, null or blank if no
		 * worksheet has been specified or if the file is not an XLS file.
		**/
		public String getTableWorksheetSource(String tableName) {
			if(tableName.equalsIgnoreCase(primaryTableName)) {
				return part.worksheetName;
			}
			return null;
		}

		/**
		 * Allow custom processing and SQL for exporting data.
		 * @param type which type of MOVES database holds the exported data.  Typically, this
		 * will be DEFAULT, EXECUTION, or null.  null indicates a user-supplied database is
		 * being used.
		 * @param db database holding the data to be exported
		 * @param tableName table being exported
		 * @return SQL to be used or null if there is no alternate SQL.
		**/
		public String getAlternateExportSQL(MOVESDatabaseType type, Connection db, 
				String tableName) {
			return null;
		}

		/**
		 * Cleanup custom processing and SQL for exporting data.
		 * @param type which type of MOVES database holds the exported data.  Typically, this
		 * will be DEFAULT, EXECUTION, or null.  null indicates a user-supplied database is
		 * being used.
		 * @param db database holding the data to be exported
		 * @param tableName table being exported
		**/
		public void cleanupAlternateExportSQL(MOVESDatabaseType type, Connection db, 
				String tableName) {
			// Nothing to do here
		}
	}

	/** Constructor **/
	public LinkSourceTypeHourImporter() {
		super("Link Source Types", // common name
				"linksourcetypehour", // XML node name
				new String[] { "LinkSourceTypeHour" } // required tables
				);
		shouldDoExecutionDataExport = true;
		shouldDoDefaultDataExport = false;
		part = new TableFileLinkagePart(this,new PartProvider());
		parts.add(part);
		basicDataHandler = new BasicDataHandler(this,dataTableDescriptor,
				new BasicDataHandlerProvider());
		dataHandler = basicDataHandler;
	}

	/**
	 * Check a RunSpec against the database or for display of the importer.
	 * @param db database to be examined.  Will be null if merely checking
	 * for whether to show the importer to the user.
	 * @return the status, or null if the importer should not be shown to the user.
	 * @throws Exception if anything goes wrong
	**/
	public RunSpecSectionStatus getProjectDataStatus(Connection db) 
			throws Exception {
		String sql;
		SQLRunner.Query query = new SQLRunner.Query();
		boolean hasError = false;
		boolean hasOnNetworkRoadTypes = false;
		boolean hasSourceTypes = false;
		
		if(db == null) {
			return new RunSpecSectionStatus(RunSpecSectionStatus.OK);
		}
		
		// only check for all source types if this run has an on-network road type
		// (off-network only runs don't need this table)
		sql = "SELECT count(linkID) as numOnNetworkLinks " +
			  "FROM link " +
			  "WHERE roadTypeID <> 1";
		try {
			query.open(db,sql);
			while(query.rs.next()) {
				int numOnNetworkLinks = query.rs.getInt(1);
				if (numOnNetworkLinks > 0) {
					hasSourceTypes = manager.tableHasSourceTypes(db,
							"select distinct sourceTypeID from " + primaryTableName,
							this,primaryTableName + " is missing sourceTypeID(s)");
					if(!hasSourceTypes) {
						return new RunSpecSectionStatus(RunSpecSectionStatus.NOT_READY);
					}
				}
			}
		} finally {
			query.close();
		}
		
		// check for any link VHT distributions not summing to one
		sql = "SELECT linkID, sum(sourceTypeHourFraction) as sourceTypeHourFractionTotal " +
			  "  FROM linksourcetypehour " +
			  "  GROUP BY linkID " +
			  "  HAVING ROUND(sourceTypeHourFractionTotal, 4) <> 1.0000";
		try {
			query.open(db,sql);
			while(query.rs.next()) {
				int tempLinkID = query.rs.getInt(1);
				float tempSumsToValue = query.rs.getFloat(2);
				addQualityMessage("ERROR: sourceTypeHourFraction sums to " + tempSumsToValue + " on linkID " + tempLinkID); 
				hasError = true;
			}
		} finally {
			query.close();
		}
		
		// check for the off-network link, which should not be in this table
		sql = "SELECT distinct linkID " +
			  "FROM linksourcetypehour " +
			  "JOIN link using (linkID) " +
			  "WHERE roadTypeID = 1;";
		try {
			query.open(db,sql);
			while(query.rs.next()) {
				int tempLinkID = query.rs.getInt(1);
				addQualityMessage("ERROR: linkID " + tempLinkID + " is the off-network link and should not be included in this table."); 
				hasError = true;
			}
		} finally {
			query.close();
		}
		
		// check for missing links
		sql = "SELECT distinct linkID " +
			  "FROM link " +
			  "LEFT JOIN linksourcetypehour using (linkID) " +
			  "WHERE sourceTypeHourFraction is NULL AND roadTypeID <> 1";
		try {
			query.open(db,sql);
			while(query.rs.next()) {
				int tempLinkID = query.rs.getInt(1);
				addQualityMessage("ERROR: linkID " + tempLinkID + " is missing."); 
				hasError = true;
			}
		} finally {
			query.close();
		}
		
		if(hasError) {
			return new RunSpecSectionStatus(RunSpecSectionStatus.NOT_READY);
		}
	
		return new RunSpecSectionStatus(RunSpecSectionStatus.OK);
	}
}
