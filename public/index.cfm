<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">

<html>
<head>
	<title>Fixed File Reader Index</title>
</head>

<body>

<h1>Fixed File Reader</h1>
<hr noshade>
<br/>
<p>After writing a parser for the umpteens fixed file that someone wanted to have loaded, I thought there needs to be a better way. Despite many years of XML, the use of complex flat files as a means of exchanging information is still fairly common.
These include EDI document, user and vendor data lists, specific updates from financial systems and other proprietary formats etc. 
So, since the "Why can't they use XML?" response is not really a solution, a more flexible system needed to be created that would handle many complex scenarios without me having to re-invent the wheel every time.
This is how the Fixed File Reader component came to be. It handles fixed files that go beyond the standard tabular layout for which native or platform tools have a good solution.
I am including starter definitions for EDI and VCF4 formats as well as walk through a basic one in the documentation to provide a taste of the complexity that can be handled using this component.
As usual please feel free to provide feedback about the good, bad, and ugly.

</p>

The following are examples of use fixed file reader in action: <br/>


<a href="FFRTest.cfm">Read Example 2 Data (Parents and Their childred)</a> <br/>

<a href="FFRTest2.cfm">Read EDI X.12 Data (850 PO document)</a> <br/>

<P>There are additional sample files in the disctribution. Please review directory
</P>

More information is available in the <a href="Fixed_File_Reader.pdf">Fixed File Reader Documentation</a>
<br/>
<hr noshade>
<small>(c) 2009 - Bilal Soylu  -- published under <a href="http://creativecommons.org/licenses/by/3.0/">Apache Creative Commons v3 license</a>.</small>

</body>
</html>
