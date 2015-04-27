<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">

<html>
<head>
	<title>Fixed File Content - EDI Sample PO</title>
</head>

<body>

<a href="index.cfm">home</a> <br/>

<cfscript>
	strDef = GetDirectoryFromPath(GetCurrentTemplatePath()) & "ExEDI.xml";
	strFile = GetDirectoryFromPath(GetCurrentTemplatePath()) & "SamplePO.txt";
	objFFR = CreateObject("Component","FixedFileReader");
	objFFR.setDebug(false);
	stcResult1=objFFR.fReadFixedFile(strFixedFilePath=strFile,strDefinition=strDef);	
</cfscript>

<table border="1">
	<tr>
		<th>EDI File</th>
		<th>Definition File</th>
	</tr>
	<tr>
		<td align="left" valign="top">
		<span id="contFile">
			<cffile action="READ" file="#strFile#" variable="strContent">
			<cfoutput><pre>#strContent#</pre></cfoutput> 
		</span>
		</td>
		<td align="left" valign="top">
			<span id="defFile">
				<cffile action="READ" file="#strDef#" variable="strContent">
				<cfoutput><pre>#HTMLEditFormat(strContent)#</pre></cfoutput> 
			</span>
		</td>
	</tr>
	<tr>
		<td colspan="2">
		<span id="result">			
			<cfdump var="#stcResult1#" expand="Yes" label="Parser Result"> 
		</span>
		</td>
	</tr>
</table>



</body>
</html>
