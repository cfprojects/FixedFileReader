<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">

<html>
<head>
	<title>Fixed File Content</title>
</head>

<body>
<a href="index.cfm">home</a> <br/>


<cfscript>
	strDef = GetDirectoryFromPath(GetCurrentTemplatePath()) & "Ex2Def.xml";
	strFile = GetDirectoryFromPath(GetCurrentTemplatePath()) & "Example2.txt";
	objFFR = CreateObject("Component","FixedFileReader");
	objFFR.setDebug(true);
	stcResult1=objFFR.fReadFixedFile(strFixedFilePath=strFile,strDefinition=strDef);	
</cfscript>

<h3>Result:</h3>
<cfdump var="#stcResult1#"> 
Done !

</body>
</html>
