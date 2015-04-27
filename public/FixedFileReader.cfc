<cfcomponent displayname="VerianFixedFileReader" hint="Reads complex fixed files for processing">
	<!--- the reader will require a fixed file defition. This can be passed in but most likely is a
		  xml file
	 (bsoylu 11-09-2009) --->
	 
	<!--- call constructor (bsoylu 12-22-2009) --->
	<cfset init()>
	
	 
	<cffunction name="fReadFixedFile" access="public" returntype="any" hint="reads fixed files, returns XML or array of structures. Requires file defition.">
	 	<cfargument name="strFixedFilePath" required="Yes" type="string" hint="the file that should be read">
		<cfargument name="strDefinition" required="Yes" type="string" hint="the file definition to use to parse file. This can be xml or reference to file path">
		<cfargument name="intReturnType" required="No" type="numeric" default="1" hint="determine what needs to be returned 1=Array of Structures, 2=XML">


		<cfscript>
			var Local = StructNew();
			var xmlDef = "";  //definition object
			var stcReturn = StructNew();	// init return variable	
			var i=0;
			
			Local.intStartTick = GetTickCount();	//start timer
			
			//determine whether the definition needs to be read from file or is supplied
			if (IsXML(Arguments.strDefinition)) {
				xmlDef = XMLParse(Arguments.strDefinition);
			} else {
				//read definition from file
				xmlDef = fReadDef(strFilePath=Arguments.strDefinition);
			}
			if (this.debug) {
				WriteOutput("FixedFileReader started at timestamp #Now()# <br/> Element counts will not include parser defined fields PARSERMATCHCASE and PARSERPARENTID.<br/><br/>");
			}
			
			//TODO: implement globals
			//Get the globals nodes (TODO:future implementation for use of globals (parse variables key value pairs))
			//Local.arrGlobals = XmlSearch(xmlDef.boncodeFixedFileDefintion,"global");
			//if (ArrayLen(Local.arrGlobals) GT 0) {
			//}
			
			//get main header (first header)
			Local.arrHeaders = XmlSearch(xmlDef.boncodeFixedFileDefintion,"header");
			//get Fixed File end of line delimiter, if it is CRLF we do not need to pass on as this it is default
			Local.strDel="";
			if (IsDefined("xmlDef.boncodeFixedFileDefintion.XmlAttributes.EndOfLine") AND xmlDef.boncodeFixedFileDefintion.XmlAttributes.EndOfLine NEQ "CRLF") {
				Local.strDel = xmlDef.boncodeFixedFileDefintion.XmlAttributes.EndOfLine;
			}

			if (ArrayLen(Local.arrHeaders) GT 0) {
				//now attempt to read the FixedFile
				fgetFile(strFilePath=Arguments.strFixedFilePath,strDel=Local.strDel);
				//run line processor with root header info to get things started
				//from here on recursive calls will keep things going until they are finished
				//fParseLines(xmlHeader=xmlDef.boncodeFixedFileDefintion[1].header[Local.intRootHeader],intIdx=1);
				for (i=1; i LTE ArrayLen(Local.arrHeaders); i++) {
					if (this.flagGlobalContinue) fParseLines(xmlHeader=Local.arrHeaders[i],intIdx=this.intIdx+1);
				}
			} else {
				// do nothing
				WriteOutput("No header node found under boncodeFixedFileDefintion. Nothind to do.<br>");
			}
			//re-build return
			Local.intEndTick = GetTickCount();
			stcReturn.ResultArray = this.arrResult;
			stcReturn.ResultQueries = this.stcResultQueries;
			stcReturn.ResultXML =""; // for future use
			stcReturn.ProcessingTime = (Local.intEndTick-Local.intStartTick)/1000;
			stcReturn.intErrLines = this.intErrCount; //lines with Errors normally conversion errors
			
			if (this.debug) WriteOutput("<br>FixedFileReader ended at timestamp #Now()# <br><br>");			
		</cfscript>
		
		 <cfreturn stcReturn>
	 </cffunction>

	 <cffunction name="fHeaderCheck" access="private" returntype="any" hint="checks where header node is valid. Returns true or throws error.">
	 	<cfargument name="xmlHeader" type="XML" required="Yes" hint="the xml defition to be used">

		<cfscript>
			var lstValidChildExp="Function,ParentField";
			//childExpression required
			if (NOT IsDefined("Arguments.xmlHeader.XmlAttributes.childExpression"))
				fThrow("childExpression is a required attribute of header node, it can be prefixed with either Function: or Field:");

			//childExpression is well formatted
			if (ListLen(Arguments.xmlHeader.XmlAttributes.childExpression,":") LT 2)
				fThrow("childExpression can only be prefixed with either Function: or Field:");

			//endExpression
			if (NOT IsDefined("Arguments.xmlHeader.XmlAttributes.endExpression"))
				fThrow("endExpression is a required attribute of header node, it can be prefixed with either Function: or Count:");

			//endExpression is well formatted
			if (ListLen(Arguments.xmlHeader.XmlAttributes.endExpression,":") LT 2)
				fThrow("endExpression needs can be prefixed with either Function: or Count:");

			//if we have a repeat directive it should be boolean
			if (IsDefined("Arguments.xmlHeader.XmlAttributes.repeat") and NOT IsBoolean(Arguments.xmlHeader.XmlAttributes.repeat) ) {
				fThrow("the specified repeat attribute on header [#Arguments.xmlHeader.XmlAttributes.childExpression#] is not boolean");
			}
		</cfscript>
	 </cffunction>


	 <cffunction name="fParseLines" access="private" hint="parse each line of fixed file using specified header / match information from definition">
	 	<cfargument name="xmlHeader" type="XML" required="Yes" hint="the xml defition to be used">
		<cfargument name="intIdx" type="numeric" required="Yes" hint="the array index to process in fixed file to start processing">
		<cfargument name="intParentIdx" type="numeric" default="0" required="no" hint="do not provide a value. this is used in recursive call">
		<cfargument name="lstCases" type="string" required="No" default="" hint="do not provide a value. this is used in recursive calls">

		<cfscript>
			var Local = StructNew();
			var intLinePointer = Arguments.intIdx;
			var flagContinue = true;
			
			if (intLinePointer LTE this.intMaxLines) {
				//validation
				fHeaderCheck(xmlHeader=Arguments.xmlHeader);
				//assignment childExpression and endExpression
				Local.ce = Arguments.xmlHeader.XmlAttributes.childExpression;	// something like Function:Left(1)
				Local.ee = Arguments.xmlHeader.XmlAttributes.endExpression;
				//set a name use the child expression
				Local.HeaderName = Local.ce;
				if (IsDefined("Arguments.xmlHeader.XmlAttributes.Name")) Local.HeaderName=Arguments.xmlHeader.XmlAttributes.Name;
				if (this.debug) WriteOutput("Starting Header [#Local.HeaderName#] at line " & Arguments.intIdx & "<br>");
	
				//determine whether we use an exit point using a count definition in endExpression, if so we do not allow repeat attribute
				Local.flagNoCountUsed = true;
				if (IsDefined("Arguments.xmlHeader.XmlAttributes.endExpression")) {
					Local.strTemp = ListFirst(Arguments.xmlHeader.XmlAttributes.endExpression,":");
					if (Local.strTemp IS "count") Local.flagNoCountUsed = false;
				};
	
				while (intLinePointer LTE this.intMaxLines AND flagContinue AND this.flagGlobalContinue) {
					Local.flagAddToQuery = false;
					if (intLinePointer LTE this.intMaxLines) {
						// get list of match cases
						Local.arrMatchCases = xmlsearch(Arguments.xmlHeader,'match');
						Local.lstMatches = fGetMatchCaseList(arrMatches=Local.arrMatchCases);
						//get the line to process and see whether we have a hit with any of the matches
						Local.intLineMatch = fMatchLine(lstMatches=Local.lstMatches,strExpression=Local.ce,idxLine=intLinePointer,idxResultParent=Arguments.intParentIdx);
						//debug
						if (this.debug AND Local.intLineMatch) {
							Local.stcMatchInfo = Local.arrMatchCases[Local.intLineMatch];
							Local.strMatchName = "";
							if (IsDefined("Local.stcMatchInfo.XmlAttributes.name")) Local.strMatchName = Local.stcMatchInfo.XmlAttributes.name;
							Local.strCond = ListGetAt(Local.lstMatches,Local.intLineMatch);
							WriteOutput("Match for [#Local.strMatchName#] on condition [#Local.ce#] to [#Local.strCond#] for line #intLinePointer#<br>");
						};
	
						//if we have a match process according to match fields and save in result array
						if (Local.intLineMatch) {
							//get remainder of match tag for processing into new variable
							Local.stcMatchInfo = Local.arrMatchCases[Local.intLineMatch];
							Local.flagIgnore = false;
							if (IsDefined("Local.stcMatchInfo.XmlAttributes.ignore") AND IsBoolean(Local.stcMatchInfo.XmlAttributes.ignore) AND Local.stcMatchInfo.XmlAttributes.ignore) Local.flagIgnore = true;
							//proceed or ignore decision
							if (Local.flagIgnore) {
								if (this.debug) WriteOutput("-- ignore directive for line #intLinePointer# found.<br>");
								this.arrResult[intLinePointer]="";
							} else {
								//handle line based on field directives
								Local.stcResult = fLineDetail(xmlMatch=Local.stcMatchInfo,strContent=this.arrFC[intLinePointer]);
								//add parser data points
								Local.stcResult.ParserParentID = Arguments.intParentIdx;
								this.arrResult[intLinePointer]= Local.stcResult;
								//set flag to add to query if needed later
								Local.flagAddToQuery = true;
								
							}; //proceed or ignore
	
							//check for child header nodes under this match node:
							//if we have a header then the next line is assumed to follow the new header rules and this newly saved one
							//becomes the parent for all subsequent lines
							Local.arrChildHeaders = xmlsearch(Local.stcMatchInfo,'header');
							if (ArrayLen(Local.arrChildHeaders)) {
								//recursive call to process subsequent lines setting current line as parent
								this.intIdx = intLinePointer;
								Local.intChildStopLine = fParseLines(xmlHeader=Local.arrChildHeaders[1],intIdx=intLinePointer+1,intParentIdx=intLinePointer);
								//check whether we need to reprocess this line or move ahead one by default we process the end line in parent as well using the same match criteria,
								//if the end line is structured differently and data in it is needed
								Local.blnReuseLastLine = true;
								if (IsDefined("Arguments.xmlHeader.XmlAttributes.restartAtLastRecord") AND IsBoolean(Arguments.xmlHeader.XmlAttributes.restartAtLastRecord))
										Local.blnReuseLastLine = Arguments.xmlHeader.XmlAttributes.restartAtLastRecord;							
										
								if (Not Local.blnReuseLastLine AND (Local.intChildStopLine+1) LT this.intMaxLines) {
									intLinePointer++;
								}
									
							}
						} //line match
	
	
	
					}; //end if
					
					//check how to handle the exit condition line, i.e. whether to process or ignore the line in we
					//found the exit condition, many times this is a wrapped line with different content and should be ignored
					//if ignored the result array for this index will be a string instead of a structure
					//if we use count argument in header node this will allways be false as the count is expected to be inclusive of the
					//last line of the record							
					if (Local.flagNoCountUsed) {
						Local.blnIgnoreEndLine = true;
					} else {
						Local.blnIgnoreEndLine = false;
					}
					if (Local.flagNoCountUsed AND IsDefined("Arguments.xmlHeader.XmlAttributes.IgnoreLastRecordData") AND IsBoolean(Arguments.xmlHeader.XmlAttributes.IgnoreLastRecordData))
						Local.blnIgnoreEndLine = Arguments.xmlHeader.XmlAttributes.IgnoreLastRecordData;
					

					//check for exit condition on this header (next line meets condition or count)					
					if (fCheckExit(strEndExpression=Local.ee,idxStartLine=Arguments.intIdx,idxCurrentLine=intLinePointer,idxParentLine=Arguments.intParentIdx)) {
						flagContinue = false;
						//reset this scope
						this.intIdx = intLinePointer;
						if (Local.blnIgnoreEndLine) {
							this.arrResult[intLinePointer]="endExpression found, line ignored";
							if (this.debug) WriteOutput("-- ignore directive for endRecord is enabled. Resetting this line.<br>");
						}
						//add to query if the flag has been set	and we are allowed to use the last line
						if (NOT Local.blnIgnoreEndLine AND Local.flagAddToQuery AND IsDefined("Local.stcMatchInfo.XmlAttributes.query") AND Local.stcMatchInfo.XmlAttributes.query NEQ "") {
							fAddToQuery(idxLine=intLinePointer,strQueryName=Local.stcMatchInfo.XmlAttributes.query,stcData=Local.stcResult);
						} 						
						
					} else {
					
						//add to query if the flag has been set						
						if (Local.flagAddToQuery AND IsDefined("Local.stcMatchInfo.XmlAttributes.query") AND Local.stcMatchInfo.XmlAttributes.query NEQ "") {
							fAddToQuery(idxLine=intLinePointer,strQueryName=Local.stcMatchInfo.XmlAttributes.query,stcData=Local.stcResult);
						} 
					
						//goto next line
						intLinePointer++;
					}
					//WriteOutput("Line " & intLinePointer & " <br>");
					//increment counter
	
				}; //end while
	
				this.intIdx = intLinePointer;
				

				
				//if this header has a repeat directive we will need to re-call the same function with a new starting point (recursive)
				//unless the endpoint has a count directive
				if (Local.flagNoCountUsed AND intLinePointer LT this.intMaxLines AND IsDefined("Arguments.xmlHeader.XmlAttributes.repeat") AND Arguments.xmlHeader.XmlAttributes.repeat) {
					//check whether we have a repeat unless directive which is another way of designating an exit condition but one that prevents repeats (repeat="Yes")
					Local.blnRepeatAllowed = true;
					if (IsDefined("Arguments.xmlHeader.XmlAttributes.repeatUnless") AND Arguments.xmlHeader.XmlAttributes.repeatUnless NEQ ""){
						Local.blnRepeatAllowed=fCheckRepeat(strEndExpression=Arguments.xmlHeader.XmlAttributes.repeatUnless,idxCurrentLine=intLinePointer);
					}
					//if we are allowed to repeat we will call again
					if (Local.blnRepeatAllowed)
						fParseLines(xmlHeader=Arguments.xmlHeader,intIdx=intLinePointer+1,intParentIdx=Arguments.intParentIdx);
				}
			}; // outer (intLinePointer LTE this.intMaxLines) we are within parsed file record count
			//send back the last line we stopped at
			return intLinePointer;
		</cfscript>			
	 </cffunction>
	 
	<cffunction name="fAddToQuery" access="private" hint="add a record to a query">
		<cfargument name="strQueryName" required="Yes" type="string" hint="name of query to which a record should be added">
		<cfargument name="stcData" required="Yes" type="struct" hint="the data which should be added to a query">
		<cfargument name="idxLine" required="No" default="0" type="numeric" hint="which line we are working on">		
		
		<cfscript>
			var Local = StructNew();
			var i=0;
			//error flag
			Local.blnError = false;			
			if (StructKeyExists(this.stcResultQueries,Arguments.strQueryName)){
				//realias
				Local.qryResult =this.stcResultQueries[Arguments.strQueryName];
				Local.lstQryCols = Local.qryResult.ColumnList;
				Local.intMaxCols = StructCount(Arguments.stcData);
				Local.lstStructCols = StructKeyList(Arguments.stcData);
				//add row
				QueryAddRow(Local.qryResult);
				//add index from processing
				QuerySetCell(Local.qryResult,"ParserRecordID",Arguments.idxLine);				
				//iterate through structure and add to query row
				for (i=1; i LTE Local.intMaxCols; i++) {					
					Local.strField = ListGetAt(Local.lstStructCols,i);
					if (ListFindNoCase(Local.lstQryCols, Local.strField) GT 0 ) {
						//we found the query col
						try {
							QuerySetCell(Local.qryResult,Local.strField,Arguments.stcData[Local.strField]);
						} catch (Any e) {
							Local.blnError=true;
							if (this.Debug) WriteOutput("-- <b>error:</b>: query adding cell [#Local.strField#] to [#Arguments.strQueryName#]: #e.message# <br>");													
						}	
					} else {
						//we do not have this query column
						Local.blnError=true;
						if (this.Debug) WriteOutput("-- <b>error:</b>: query object [#Arguments.strQueryName#] does not contain field [#Local.strField#].<br>");						
					}		
				}// end of loop			
			} else {
				Local.blnError=true;
				if (this.Debug) WriteOutput("-- <b>error:</b>: query object [#Arguments.strQueryName#] does not exist.<br>");
			};
			
			
			//check whether we know the query			
			if (Local.blnError) this.intErrCount++;
		</cfscript>
		<!--- if the query exists verify the colums, if the columns don't exist add them (bsoylu 11-13-2009) --->
	</cffunction>


	
	<cffunction name="fLineDetail" access="private" returntype="struct" hint="break line data into structure keys based on field defition provided">
		<cfargument name="xmlMatch" type="xml" required="yes" hint="the match tag used to analyze this line">
		<cfargument name="strContent" type="string" required="yes" hint="the line content to be analyzed">

		<cfscript>
			var stcReturn = StructNew();
			var arrFields = xmlsearch(Arguments.xmlMatch,'field');
			var i=0;
			var Local = StructNew();
			
			//prep for query creation if needed
			Local.strQueryName="";
			Local.lstFieldNames ="ParserRecordID,ParserParentID,ParserMatchCase";
			Local.lstFieldTypes ="integer,integer,varchar"; 
			Local.blnCreateQuery = false;

			//check whether we need to create a query object
			if (IsDefined("Arguments.xmlMatch.XmlAttributes.query") and Arguments.xmlMatch.XmlAttributes.query NEQ "") {
				Local.strQueryName=Arguments.xmlMatch.XmlAttributes.query;
				if (NOT StructKeyExists(this.stcResultQueries,Local.strQueryName)){
					// we do not know this query, we need to create it
					Local.blnCreateQuery = true;					
				}			
			}

			//iterate through fields if no segmentDel has been provided
			if (IsDefined("Arguments.xmlMatch.XmlAttributes.segmentDel") OR ArrayLen(arrFields) GT 0) {

			
				if (IsDefined("Arguments.xmlMatch.XmlAttributes.segmentDel")) {
					//there is record delimiter defined use it to split line up
					Local.Del = Arguments.xmlMatch.XmlAttributes.segmentDel;
					if (Local.Del IS "tab") Local.Del = Chr(9); //translation for tab
					if (Local.Del IS "comma") Local.Del = ","; //translation for tab
					Local.arrSplitContent = ListToArray(Arguments.strContent,Local.Del);

					//iterate through array and build return structure
					for (i=1;i LTE ArrayLen(Local.arrSplitContent); i++) {
						//when supplying a segment delimiter fields definitons are optional
						Local.strKey = "Field" & Right("000" & i,3);
						Local.stcField =StructNew();
						Local.strValue=Trim(Local.arrSplitContent[i]);
						if (i LTE ArrayLen(arrFields)) {
							Local.strKey = arrFields[i].XmlAttributes.name;
							Local.stcField =arrFields[i];
							//validation content based on content type attributes
							Local.strValue = fTypeProcessing(Input=Local.strValue,stcDef=Local.stcField);
						};
						//capture values that may help with query creation if we need to create an empty query
						if (Local.blnCreateQuery) {
							Local.lstFieldNames = ListAppend(Local.lstFieldNames,Local.strKey);
							//currently we only create numeric or text fields for queries
							if (IsDefined("Local.stcField.XmlAttributes.type") AND  Local.stcField.XmlAttributes.type IS "numeric") {
								Local.lstFieldTypes = ListAppend(Local.lstFieldTypes,"decimal");
							} else {
								Local.lstFieldTypes = ListAppend(Local.lstFieldTypes,"varchar");
							}
						};
						//add to struct
						stcReturn[Local.strKey] =Local.strValue;
					}
				} else {
					//split the fields up based on length and count arguments in fields definition
					Local.intOffset = 1;
					for (i=1;i LTE ArrayLen(arrFields); i++) {
						//get field start and count
						Local.stcField =arrFields[i];
						Local.strKey = arrFields[i].XmlAttributes.name;
						Local.intCount = Val(arrFields[i].XmlAttributes.count);
						Local.strValue=Trim(Mid(Arguments.strContent,Local.intOffset,Local.intCount));
						//validation content based on content type attributes
						Local.strValue = fTypeProcessing(Input=Local.strValue,stcDef=Local.stcField);
						//add to result
						stcReturn[Local.strKey] =Local.strValue;
						//add to offset
						Local.intOffset = Local.intOffset + Local.intCount;
						
						//capture values that may help with query creation if we need to create an empty query
						if (Local.blnCreateQuery) {
							Local.lstFieldNames = ListAppend(Local.lstFieldNames,Local.strKey);							
							//currently we only create numeric or text fields for queries
							if (IsDefined("Local.stcField.XmlAttributes.type") AND  Local.stcField.XmlAttributes.type IS "numeric") {
								Local.lstFieldTypes = ListAppend(Local.lstFieldTypes,"decimal");								
							} else {
								Local.lstFieldTypes = ListAppend(Local.lstFieldTypes,"varchar");
							}
						};						
					}

				}



			} // iterate through fields
			
			//create new empty query if we needed to, we should now have the fieldnames and types
			if (Local.blnCreateQuery) {
				this.stcResultQueries[Local.strQueryName] = QueryNew(Local.lstFieldNames,Local.lstFieldTypes);
				if (this.Debug) WriteOutput("-- query object [#Local.strQueryName#] created.<br>");
			}
			
			
			if (this.Debug) WriteOutput("-- parsed #StructCount(stcReturn)# elements<br>");
			//add match case info into return structure this throws off the count from above
			stcReturn.ParserMatchCase = Arguments.xmlMatch.XmlAttributes.case;
			return stcReturn;
		</cfscript>


	</cffunction>

	<cffunction name="fTypeProcessing" access="private" hint="validate record type and apply formatting">
		<cfargument name="Input" required="yes" type="string" hint="the input value to be validate">
		<cfargument name="stcDef" required="yes" hint="the definition from field xml">
		<!---
			the stcDef may contain additional info on how to process the input
				type = one of the valid types: numeric,text,date
				Format = hint about the format of input argument. If prefixed by Function: a processing directive to format the content
				ValidList=CSV list of valid values for the input
				We translate these into the arguments
		--->



		<cfscript>
			var strReturn = Arguments.Input;
			var Local = StructNew();
			//determine additional validation options for this datapoint
			Local.Format="";
			Local.Type="text";
			Local.ValidList="";

			if (IsDefined("Arguments.stcDef.XmlAttributes.type")) Local.type = Arguments.stcDef.XmlAttributes.type;
			if (IsDefined("Arguments.stcDef.XmlAttributes.Format")) Local.Format = Arguments.stcDef.XmlAttributes.Format;
			if (IsDefined("Arguments.stcDef.XmlAttributes.ValidList")) Local.ValidList = Arguments.stcDef.XmlAttributes.ValidList;

			switch (Local.type) {
				case "numeric":
					strReturn = Val(strReturn);
					break;
				case "date":
					//todo: implement via a seperate function to do date validation using format attribute information, e.g. Format="YYYYMMDD"
					if (LSIsDate(strReturn)) strReturn = LSParseDateTime(strReturn);
					break;
			}
			//check for valid list check if we cannot find value we will stop
			if (Local.ValidList NEQ "" AND ListFindNoCase(Local.ValidList,strReturn) IS 0) {
				fThrow("Cannot validate data point. Original [#Arguments.Input#] / Formatted [#strReturn#] is not one of [#Local.ValidList#].");
			}
			//formatting check for function. this can be expanded to add more directives
			if (ListFirst(Local.Format,":") IS "Function") {
				switch (ListRest(Local.Format,":")) {
					case "DIV100":
						if (IsNumeric(strReturn)) strReturn = strReturn/100;
						break;
					case "DIV1000":
						if (IsNumeric(strReturn)) strReturn = strReturn/1000;
						break;	
					default:
						if (this.debug) WriteOutput("unknown format function:" & ListRest(Local.Format,":") & "<br/>");
					break;					
				}
			}
			return strReturn;
		</cfscript>

	</cffunction>

	
	<cffunction name="fCheckRepeat" access="private" returntype="boolean" hint="determines whether the following line would prevent a repeat directive from being used. We do not restart a repeat if the condition is met.">

	 	<cfargument name="strEndExpression" required="Yes" type="string" hint="which expression is used to determine whether we have reached the end of repeat">
		<cfargument name="idxCurrentLine" required="Yes" type="numeric" hint="which line are we currently processing">

		<cfscript>
			var blnExit = true;
			var strLine= "";
			var Local=StructNew();
			var blnRepeat=true;
			
			
			if (Arguments.idxCurrentLine LT this.intMaxLines) {
		
				//set defaults, we will look at the following line to see whether it meets our exit condition
				Local.ExitCount =0;
				Local.intNextLine = Arguments.idxCurrentLine + 1;
				strLine= this.arrFC[Local.intNextLine];
				
				switch (ListFirst(Arguments.strEndExpression,":")) {
	
					case "Function":
						//get expression and replace question mark with strLine
						Local.strExp = ListRest(Arguments.strEndExpression,":");
						Local.strExp = Replace(Local.strExp,"?","strLine");
						
						blnExit = Evaluate(Local.strExp);
						if (Not IsBoolean(blnExit)) blnExit=true; //force to exit
	
						break;
					
					default:
						fThrow("the header node does not have one of the valid attribute for repeatUnless. (repeatUnless requires an evaluation function)");
				}
	
				//debug
				if (blnExit and this.debug) {				
					WriteOutput("repeatUnless stop for header detected using expression [#Arguments.strEndExpression#] at line: " & Local.intNextLine & "<br/>");
				}
				blnRepeat = Not blnExit;
			}; // we have one more line left for which we can check a condition
			return blnRepeat;
		</cfscript>
	</cffunction>	
	
 	<cffunction name="fCheckExit" access="private" returntype="boolean" hint="determines whether we have reached the end of a segment or end of file and sets flags to stop processing">

	 	<cfargument name="strEndExpression" required="Yes" type="string" hint="which expression is used to determine whether we have reached the end of a given header">
		<cfargument name="idxStartLine" required="Yes" type="numeric" hint="which line did this header start on">
		<cfargument name="idxCurrentLine" required="Yes" type="numeric" hint="which line are we currently processing">
		<cfargument name="idxParentLine" required="No" default="0" type="numeric" hint="if there is a parent line, what ID">
		
		<cfscript>
			var blnExit = true;
			var strLine= this.arrFC[Arguments.idxCurrentLine];
			var Local=StructNew();
			//global stop check (any of the recursive calls may exceed processing realm)
			if (Arguments.idxCurrentLine GTE this.intMaxLines) {
				this.flagGlobalContinue=false;
			}
			//now check whether we should continue
			Local.ExitCount =0;

			switch (ListFirst(Arguments.strEndExpression,":")) {

				case "Function":
					//get expression and replace question mark with strLine
					Local.strExp = ListRest(Arguments.strEndExpression,":");
					Local.strExp = Replace(Local.strExp,"?","strLine");

					blnExit = Evaluate(Local.strExp);
					if (Not IsBoolean(blnExit)) blnExit=true; //force to exit

					break;
				case "Count":
					//check whether the argument is field name or a number, a field name should be a numeric field in the
					//parent record
				    Local.CountField = ListRest(Arguments.strEndExpression,":");
					if (IsNumeric(Local.CountField)) {
						//will need to get current count of processed lines under this header
						Local.ExitCount = Val(ListRest(Arguments.strEndExpression,":"));						
						if (Local.ExitCount GT 0 AND  ((Arguments.idxCurrentLine-Arguments.idxStartLine+1 ) LT Local.ExitCount)) {
							blnExit=false;
						}
					} else if (Arguments.idxParentLine GT 0) {
						//check whether this is a known struct element in parent and retrieve it
						Local.stcParent = this.arrResult[Arguments.idxParentLine];
						if (IsStruct(Local.stcParent) AND StructKeyExists(Local.stcParent,Local.CountField)){
							//turn this into a number and make assessment, an alpha numeric value becomes zero
							Local.ExitCount = Val(Local.stcParent[Local.CountField]);							
							if (Local.ExitCount GT 0 AND ((Arguments.idxCurrentLine-Arguments.idxStartLine+1 ) LT Local.ExitCount)) {
								blnExit=false;
							}						
						} else {
							//no such field in structure
							blnExit=true;
							if (this.debug) WriteOutput("<b>error:</b> cannot determine parent field at index [#Arguments.idxParentLine#] for endExpression count based on [#Arguments.strEndExpression#] at line: " & Arguments.idxCurrentLine & "<br/>");						
						}					
					} else {
						//we do not know how to find the end of a header we need to stop
						blnExit=true;
						if (this.debug) WriteOutput("<b>error:</b> cannot determine endExpression count based on [#Arguments.strEndExpression#] at line: " & Arguments.idxCurrentLine & "<br/>");
					}
					break;
				default:
					fThrow("the header node does not have one of the valid attribute for endExpression");
			}

			//debug
			if (blnExit and this.debug) {
				if (Local.ExitCount) WriteOutput("-- used count indicator showing #Local.ExitCount# records <br/>");
				WriteOutput("End of header detected using expression [#Arguments.strEndExpression#] at line: " & Arguments.idxCurrentLine & "<br/>");
			}
			return blnExit;
		</cfscript>
	</cffunction>

	<cffunction name="fThrow" access="private" hint="alias to cfthrow tag to use in scripts">
	 	<cfargument name="strDetail" type="string" required="Yes" hint="the detail to be thrown">
		<cfthrow type="FixedFileReader" detail="error on or below line [#this.intIdx#]:#Arguments.strDetail#">
	</cffunction>

	 
	<cffunction name="fDump" access="private" hint="alias to cfdump tag to use in scripts">
	 	<cfargument name="varDump" required="Yes" hint="the detail to be dumped">
		<cfdump var="#Arguments.varDump#">
	</cffunction>	

	<cffunction name="fMatchLine" access="private" returntype="numeric" hint="attempts to run match for line. return which match was found as index of the list.">
	 	<cfargument name="lstMatches" required="Yes" type="string" hint="list of possible matches">
	 	<cfargument name="strExpression" required="Yes" type="string" hint="which expression is used to determine match">
		<cfargument name="idxLine" required="Yes" type="numeric" hint="which line we are working on">
		<cfargument name="idxResultParent" required="no" default="0" type="numeric" hint="if this is second or third level record we may match on parent field content. We will need the last parent record index.">


		 <cfscript>
		 	var Local = StructNew();
		 	var intReturn=0; //if zero is returned this line could not be matched with a match node
			var strLine= this.arrFC[Arguments.idxLine];

			switch (ListFirst(Arguments.strExpression,":")) {

				case "Function":
					//get expression and replace question mark with strLine
					Local.strExp = ListRest(Arguments.strExpression,":");
					Local.strExp = Replace(Local.strExp,"?","strLine");
					Local.Value =  Evaluate(Local.strExp);
					break;
				case "ParentField":
					//will need to get data from previous result
					if (Arguments.idxResultParent GT 1) {
						Local.strKey = ListRest(Arguments.strExpression,":");
						Local.stcPrevRec = this.arrResult[Arguments.idxResultParent];
						if (StructKeyExists(Local.stcPrevRec, Local.strKey)) {
							Local.Value = Local.stcPrevRec[Local.strKey];
						} else {
							fThrow("the specified Field: [#Local.strKey#] was not found in parent records [processing Line: #Arguments.idxLine#]");
						}

					}
					Local.intMaxProcessed = ArrayLen(this.arrResult);

					break;
				default:
					fThrow("the header node does not have one of the valid prefixes Field: or Function:");
			}
			//see if any of the match conditions would apply to this line. Will only process the first matching condition
			intReturn = ListFindNoCase(Arguments.lstMatches,Local.Value);
		 	return intReturn;
		 </cfscript>
	 </cffunction>

	 <cffunction name="fGetMatchCaseList" access="private" returntype="string" hint="analyze the match option and return a CSV list of match elements">
	 	<cfargument name="arrMatches" required="Yes" type="array" hint="the match array of the xml definition used">

		<cfset var idxMatch="">
		<cfset var lstReturn="">

		<cfloop index="idxMatch" array="#Arguments.arrMatches#">
			<cfif IsDefined("idxMatch.XmlAttributes.case")>
   				<cfset lstReturn = ListAppend(lstReturn,idxMatch.XmlAttributes.case)>
			<cfelse>
				<!--- need to throw error (bsoylu 11-09-2009) --->
				<cfthrow type="FixedFileReader" detail="case is a required attribute of the match node. It can contain any alpha numeric match except comma.">
			</cfif>
   		</cfloop>

	 	<cfreturn lstReturn>
	 </cffunction>

	 <cffunction name="fgetFile" access="private" hint="reads content of fixed file and placed into array">
	 	<cfargument name="strFilePath" required="Yes" type="string" hint="file path to fixed file">
		<cfargument name="strDel" required="No" type="string" hint="end of line delimiter. If not present CRLF is assumed">
		<cfset var strFileContent="">
		<cfset var strEOL = Chr(10) & Chr(13)>

		<!--- determine delimiter, we will accept certain keywords LF,CR,CRLF,TAB as well (bsoylu 11-09-2009) --->
		<cfif IsDefined("Arguments.strDel") and Arguments.strDel NEQ "">
			<cfif Arguments.strDel IS "LF">
				<cfset strEOL = Chr(10)>
			<cfelseif Arguments.strDel IS "CR">
				<cfset strEOL = Chr(13)>
			<cfelseif Arguments.strDel IS "CRLF">
				<cfset strEOL = Chr(10) & Chr(13)>
			<cfelseif Arguments.strDel IS "TAB">
				<cfset strEOL = Chr(9)>
			<cfelse>
				<cfset strEOL =Arguments.strDel>
			</cfif>			
		</cfif>

		<cfif FileExists(Arguments.strFilePath)>
			<cffile action="READ" file="#Arguments.strFilePath#" variable="strFileContent">
			<!--- turn content into Array and store in this scope (bsoylu 11-09-2009) --->
			<cfset this.arrFC = ListToArray(strFileContent,strEOL)>
			<cfset this.intMaxLines = ArrayLen(this.arrFC)>
			<cfset ArrayResize(this.arrResult,this.intMaxLines)>
		<cfelse>
			<cfthrow type="FixedFileReader" detail="fixed file [#Arguments.strFilePath#] not found.">
		</cfif>

	 </cffunction>


	 <cffunction name="fReadDef" access="private" hint="reads defition file">
	 	<cfargument name="strFilePath" required="Yes" type="string" hint="file path to defintion">
		<cfset var xmlFileContent="">
		<cfif FileExists(Arguments.strFilePath)>
			<cftry>
				<cfset xmlFileContent=XMLParse(Arguments.strFilePath)>
				<cfcatch type="Any">
					<cfthrow type="FixedFileReader" detail="the definition file is not well formed XML.">
				</cfcatch>
			</cftry>
		<cfelse>
			<cfthrow type="FixedFileReader" detail="required Definition file not present">
		</cfif>
		<cfreturn xmlFileContent>
	 </cffunction>

	<!--- init (bsoylu 12-22-2009) --->
	<cffunction name="init" access="public" hint="initialize or reset component variables">
		<cfset this.arrResult = ArrayNew(1)>
		<cfset this.arrFC = ArrayNew(1)> <!--- file content as array (bsoylu 11-09-2009) --->
		<cfset this.intMaxLines =0>
		<cfset this.intIdx =0> <!--- start pointer into file array where we will store the fixed file content (bsoylu 11-09-2009) --->
		<cfset this.intPrevHeaderIdx =0> <!--- pointer in result array for last succesfull processed element header that was different from the curent one (bsoylu 11-09-2009) --->
		<cfset this.flagGlobalContinue = true> <!--- overall flag for line parsing to stop parsing if we have reached end of file (bsoylu 11-10-2009) --->
		<cfset this.debug=true> <!--- defines debug output is on or of bsoylu 11/10/2009 --->
		<cfset this.stcResultQueries = StructNew()> 
		<cfset this.intErrCount =0>  <!--- lines with errors (bsoylu 11-16-2009) --->
		<cfset this.stcGlobals = StructNew()>	
	</cffunction>

    <!--- getters and setters below --->
	<cffunction  name="setDebug" returntype="boolean" hint="sets and gets debug flag. returns current setting.">
		<cfargument name="Debug" type="boolean" hint="whether debug is on or off.">
		<cfif IsDefined("Arguments.Debug")>
			<cfset this.debug = Arguments.Debug>
		</cfif>
		<cfreturn this.debug>
	</cffunction>

</cfcomponent>
