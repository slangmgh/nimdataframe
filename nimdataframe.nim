{.deadCodeElim: on.}
##
##   Library     : nimdataframe.nim
##
##   Status      : development
##
##   License     : MIT opensource
##
##   Version     : 0.0.2
##
##   ProjectStart: 2016-09-16
##   
##   Latest      : 2017-10-20
##
##   Compiler    : Nim >= 0.17.2
##
##   OS          : Linux
##
##   Description : 
##   
##                 simple dataframe 
##                 
##                 create a dataframe for display or processing
##                 
##                 from online or local csv files
##                 
##                 able to create subdataframes from dataframes and sorting on columns and column statistics
##
##
##   Usage       : import nimdataframe
##
##   Project     : https://github.com/qqtop/NimDataFrame
##
##   Docs        : http://qqtop.github.io/nimdataframe.html
##
##   Tested      : OpenSuse Tumbleweed 
## 
##   Todo        : additional calculations on dataframes
##                 allow right or left align for each column
##                 improve tests and example
##                 dataframe names
##                 
##  
##   Notes       :   
##  
##  
import os
import nimcx,httpclient,browsers
import parsecsv,streams,algorithm,stats
import db_sqlite
import typetraits,typeinfo
export stats

let NIMDATAFRAMEVERSION* = "0.0.2"

const 
      asc*  = "asc"
      desc* = "desc"
         
type        
    nimss* = seq[string]         # nim string seq
    nimis* = seq[int]            # nim integer seq
    nimfs* = seq[float]          # nim float seq
    nimbs* = seq[bool]           # nim bool seq
    
type
    nimdf* =  ref object         
           df* : seq[nimss]     # nim data frame 
           hasHeader* : bool
           colcount*  : int
           rowcount*  : int
           colcolors* : nimss
           colwidths* : nimis
           colHeaders*: nimss
           rowHeaders*: nimss
    
proc newNimDf*():nimdf = 
           new(result)            # needed for ref object  gc managed
           result.df = @[]
           result.hasHeader  = false
           result.colcount   = 0
           result.rowcount   = 0
           result.colcolors  = @[]
           result.colwidths  = @[]
           result.colHeaders = @[]
           result.rowHeaders = @[]  # not yet in use
           
           
           
proc newNimSs*():nimss = @[]
proc newNimIs*():nimis = @[]
proc newNimFs*():nimfs = @[]
proc newNimBs*():nimbs = @[]

proc createDataFrame*(filename:string,cols:int = 2,rows:int = -1,sep:char = ',',hasHeader:bool = false):nimdf 

# used in sortdf
var intflag:bool = false
var floatflag:bool = false
var stringflag:bool = false


proc getData1*(url:string):auto =
  ## getData
  ## 
  ## used for internet based data in csv format
  ## 
  try:
       var zcli = newHttpClient()
       result  = zcli.getcontent(url)   # orig test data
  except :
       printLnBiCol("Error : " & url & " content could not be fetched . Retry with -d:ssl",red,bblack,":",0,true,{}) 
       printLn(getCurrentExceptionMsg(),red,xpos = 9)
       doFinish()

converter toNimis*(s:seq[int]):nimis = 
         var z = newNimIs()
         for x in 0.. <s.len: z.add(s[x])
         return z   
        

proc makeDf1*(ufo1:string,hasHeader:bool = false):nimdf =
   ## makeDf
   ## 
   ## used to create a dataframe with data string received from getData1
   ## 
   #printLn("Executing makeDf1",peru)
   
   var ufol = splitLines(ufo1)
   var df = newNimDf()
  
   var ufos = ufol[0].split(",")
   var ns = newNimSs()
           
   #df.colwidths = @[toNimis(toSeq(0..<ufos.len))]
   df.colwidths = toNimis(toSeq(0..<ufos.len))
   
   for x in 0.. <ufol.len:
      ufos = ufol[x].split(",")  # problems may arise if text has commas ... then need some preprocessing
      ns = newNimSs()
      #var wdc = 0
      for xx in 0.. <ufos.len:
          ns.add(ufos[xx].strip(true,true))
          #if wdc == df.colwidths.len: wdc = 0
          #if df.colwidths[wdc][xx] < ufos[xx].len: 
          #   df.colwidths[wdc].add(ufos[xx].strip(true,true).len)
          #inc wdc     
          if df.colwidths[xx] < ufos[xx].len: 
             df.colwidths.add(ufos[xx].strip(true,true).len)
          
      df.df.add(ns)
   
   df.rowcount = df.df.len
   df.colcount = df.df[0].len
   df.hasHeader = hasHeader
   result = df  


proc getData2*(filename:string,cols:int = 2,rows:int = -1,sep:char = ','):auto = 
    ## getData2
    ## 
    ## used for csv files with a path and filename available
    ## 
 
    # we read by row but add to col seqs --> so myseq contains seqs of col data 
    var csvrows = -1                # in case of getdata2 csv files we may get processed rowcount back
    var ccols = cols 
    var rrows = rows
    if rrows == -1 : rrows = 50000  # limit any dataframe to 50000 rows if no rows param given
    var x: CsvParser
    var s = newFileStream(filename, fmRead)
    if s == nil: 
            printLnBiCol("Error : " & filename & " content could not be accessed.",red,bblack,":",0,true,{}) 
            printLn(getCurrentExceptionMsg(),red,xpos = 9)
            doFinish()
    else: 
        # we need to check if required cols actually exist or there will be an error
        open(x, s, filename,separator = sep)
        # we read one row:
        discard readRow(x)
        var itemcount = 0
        for val in items(x.row): inc itemcount
        close(x)
        close(s)
        
        # now we make sure that the passed in cols is not larger than itemcount
        if ccols > itemcount: ccols = itemcount
        
        var myseq = newNimDf()
        for x in 0.. <ccols:  myseq.df.add(@[])
           
        # here we actually use everything
        s = newFileStream(filename, fmRead)
        open(x, s, filename,separator = sep)
        var dxset = newNimSs()
        var c = 0  # counter
        try:
          while readRow(x) and csvrows < rrows: 
          
              try:   
                    for val in items(x.row):
                      if c < ccols :
                        dxset.add(val)
                        myseq.df[c].add(dxset)   
                        inc c
                        dxset = @[]
                    c = 0  
              except:
                    c = 0
                    discard
              
              csvrows = processedRows(x)
        except CsvError: 
           discard
        
        close(x)
        myseq.rowcount = csvrows
        myseq.colcount = ccols
        result = myseq    # this holds col data now
        
        
proc makeDf2*(ufo1:nimdf,cols:int = 0,hasHeader:bool = false):nimdf =
   ## makeDf2
   ## 
   ## used to create a dataframe with nimdf object received from getData2  that is local csv
   ## note that overall it is better to preprocess data to check for row quality consistency
   ## which is not done here yet , so errors may show
   #printLn("Executing makeDf2",peru)

   var df = newNimDf()       # new dataframe to be returned
   var arow = newNimSs()     # one row of the data frame
   
   # now need to get the col data out and massage into rows
 
   try:
       df.colcount = ufo1.df.len  
       df.rowcount = ufo1.df[0].len  # this assumes all cols have same number of rows maybe should check this
       df.hasHeader = ufo1.hasHeader
   except IndexError:
       printLn("df.colscount = " & $df.colcount,red)
       printLn("df.rowscount= " & $df.rowcount,red)
       printLn("IndexError raised . Exiting now...",red)
       doFinish()  
  
   for rws in 0.. <df.rowcount:     # rows count  
     arow = @[]
     var olderrorrow = 0            # so we only display errors once per row
     for cls  in 0.. <df.colcount:  # cols count  
       # now build our row 
       try: 
            
            arow.add(ufo1.df[cls][rws])      
       except IndexError:
            printLn("Error row :  " & $arow,red)
            try:
                 printLn("ufo1   = " & $ufo1.df[cls][rws],red)
            except IndexError:
                 printLn("Invalid row data found ! Check for empty rows ,missing columns data etc. in the data file",red)
                 
            printLn("IndexError position at about: ",red)      
            if rws <> olderrorrow:
               printLnBiCol("column : " & $cls,yellowgreen,truetomato,":",6,false,{})
               printLnBiCol("row    : " & $rws,yellowgreen,truetomato,":",6,false,{})
               echo()
            olderrorrow = rws  
            # we could stop here too
            #printLn("Exiting now...",red)
            #doFinish()   
            
     df.df.add(arow)   
     df.hasHeader = hasHeader
   result = df  


   
      
proc getColHdx(df:nimdf): nimss =
      ## getColHeaders
      ## 
      ## get the first line of the dataframe df 
      ## 
      ## we assume line 0 contains headers
      ## 
     
      result = newNimss()
      for hx in df.df[0]:
         result.add(hx.strip(true,true))      

proc getTotalHeaderColsWitdh*(df:nimdf):int = 
     ## getTotalHeaderColsWitdh
     ## 
     ## sum of all headers width
     ## 
     result = 0
     var ch = getcolhdx(df)
     for x in 0.. <ch.len:
         result = result + ch[x].strip(true,true).len

proc showHeader*(df:nimdf) = 
   ## showHeader
   ## 
   ## shows first 2 lines of df incl. headers if any of dataframe
   ## 

   printLnBiCol("hasHeader :  " & $df.hasHeader,xpos = 2)
   printLn("Dataframe first 2 rows :",yellowgreen,xpos = 2,styled = {})
   printLn(df.df[0],xpos = 2)
   printLn(df.df[1],xpos = 2)
   echo()
   
   
proc showCounts*(df:nimdf) =    
   printLnBiCol("Columns   :  " & $df.colcount & spaces(3),xpos = 2)
   printLnBiCol("Data Rows :  " & $df.rowcount,xpos = 2)
   printLn("Row count includes header in data source",xpos=2)
    

proc colFitMax*(df:nimdf,cols:int = 0,adjustwd:int = 0):nimis =
  ## colFitMax
  ## 
  ## calculates best column width to fit into terminal width
  ## 
  ## all column widths will be same size
  ## 
  ## cols parameter must state number of cols to be shown default = all cols
  ## 
  ## if the cols parameter in showDf is different an error will be thrown
  ## 
  ## adjustwd allows to nudge the column width if a few column chars are not shown
  ## 
  ## which may happen if no frame is shown
  ## 
  
  var ccols = cols
  if ccols == 0:
     ccols = df.colcount
  
  var optcolwd = tw div ccols - ccols + adjustwd  
  var cwd = newNimIs()
  for x in 0.. <ccols: cwd.add(optcolwd)
  result = cwd
  
  
proc checkDfOk(df:nimdf):bool =
     if df.df.len > 0:  result = true
     else:
        printLnBiCol("ERROR  : Dataframe has no data. Exiting .. ",red,red,":",0,false,{})
        result = false

       
proc showDf*(df:nimdf,rows:int = 10,cols:nimis = @[],colwd:nimis = @[], colcolors:nimss = @[], showframe:bool = false,
              framecolor:string = white,showHeader:bool = false,headertext:nimss = @[],leftalignflag:bool = false,xpos:int = 1) =
    ## showDf
    ## 
    ## Displays a dataframe 
    ## 
    ## allows selective display of columns , with column numbers passed in as a seq
    ## 
    ## Convention :  the first column = 1 
    ## 
    ## 
    ## number of rows default =  10
    ## 
    ## with cols from left to right according to cols default = 2
    ## 
    ## column width default = 15
    ## 
    ## an equal columnwidth can be achieved with colwd = colfitmax(df,0) the second param is to nudge the width a bit if required
    ## 
    ## showFrame  default = off
    ## 
    ## showHeader indicates if an actual header is available
    ## 
    ## frame character can be shown in selectable color
    ## 
    ## headerless data can be show with headertext supplied
    ##
    ## cols,colwd,colcolors parameters seqs must be of equal length and corresponding to each other
    ## 
    #
    
    var okcolwd = colwd 
    var nofirstrowflag = false    
    if checkDfok(df) == false:  doFinish()
      
    var header = showHeader
    if header == true and df.hasHeader == false: header = false   # this hopefully avoids first line is header display
    if header == false and df.hasHeader == true: nofirstrowflag = true
    if header == false and df.hasHeader == true and headertext != @[] : nofirstrowflag = false
    
    var frame  = showFrame
    let vfc  = "|"               # vertical frame char for column separation
    let vfcs = "|"               # efs2 or efb2   # vertical frame char for left (and right side <--- needs to be implemented )
    let hfct = efs2   # "_"      # horizontal framechar top of frame
    let hfcb = efs2              # horizontal framechar for bottom of frame
    if cols.len == 1:
        # to display one column data showheader and showFrame must be false
        # to avoid messed up display , Todo: take care of this eventually 
        header = false
        frame = false
    
    if cols.len != okcolwd.len:
       okcolwd = colfitmax(df,cols.len)   # try to best fit rather than to throw error
          
    # turn this one if you want this info
    #if cols.len != colcolors.len:
    #   printLnBiCol("NOTE  : Dataframe columns cols and colcolors parameter are of different length",":",red,peru)
     
    if df.df[0].len == 0: 
       printLnBiCol("ERROR : Dataframe appears to have no columns. See showDf command. Exiting ..",red,truetomato,":",0,false,{})
       quit(0)
    
  
    var okrows = rows
    var okcols = cols
     
    var toplineflag = false
    var displaystr = ""   
    var okcolcolors = colcolors
    
    # dynamic col width with colwd passed in if not colwd for all cols = 15 
         
    if okcolwd.len < okcols.len:
       # we are missing some colwd data we add default widths
       while okcolwd.len < okcols.len: okcolwd.add(15)
      
    
    # if not cols seq is specified we assume all cols
    if okcols == @[] and df.colcount > 0:
      try:
             okcols = toSeq(0..<df.colcount)    # note column indexwise numbering starts at 0 , first col = 0             
      except IndexError:
             currentLine()
             raise
   
    
    #  need a check to see if request cols actually exist
    for col in okcols:
      if col > df.colcount:
         printLn("Error : showDf needs correct column specification parameters",red) 
         printLn("Error : Requested Column >= " & $col & " does not exist in dataframe , which has " & $df.colcount & " columns",red)
         # we exit
         doFinish()
   
    # set up column text and background color
    
    if okcolcolors == @[]: # default lightgrey on black
        var tmpcols = newNimSs()
        for col in 0.. <okcols.len:
            tmpcols.add(lightgrey)
        okcolcolors = tmpcols   
           
    else: # we get some colors passed in but not for all columns  , unspecified colors are set to lightgrey    
      
        var tmpcols = newNimSs()
        tmpcols = okcolcolors
        while tmpcols.len < okcols.len  :
                 tmpcols.add(lightgrey)
        okcolcolors = tmpcols         
                   
   
    # calculate length of topline of frame based on cols and colwd 
    var frametoplinelen = 0
    assert okcols.len == okcolwd.len
    frametoplinelen = frametoplinelen + sum(okcolwd) +  (2 * okcols.len) + 1
    
    # take care of over lengths
    if okrows == 0 or okrows > df.df.len: okrows = df.df.len
     
    var headerflagok = false 
    var bottomrowflag = false 
    var ncol = 0 
    
    
    if nofirstrowflag == true:
      for brow in 1.. <okrows:   # note we get okrows data rows back and the header
        var row = brow       
        for col in 0.. <okcols.len:
           
          ncol = okcols[col] - 1
          if ncol < 0: ncol = 0
         
          try:                    
                displaystr = $df.df[row][ncol]  # will be cut to size by fma below to fit into colwd
          except IndexError:
                # if row data not available we put NA , the actual df column does not contain NA
                displaystr = "NA"          
          
          var colfm = ""
          var fma   = newSeq[string]()
          if leftalignflag == true:
              colfm = "<" & $(okcolwd[col])  # constructing the format string
          else:
              colfm = ">" & $(okcolwd[col])  # constructing the format string
          fma = @[colfm,""]  
          
          # new setup 6 display options
          
          #noframe noheader           1 ok
          #noframe firstlineheader    2 ok   
          #noframe headertextheader   3 ok
          
          # ok for more than 1 col  
          #frame   noheader           4 ok
          #frame   firstlineheader    5 ok   
          #frame   headertextheader   6 ok
          
          if frame == false:
          
                if header == false and headertext == @[] :
                            if col == 0 :
                                print(fmtx(fma,displaystr,spaces(2)),okcolcolors[col],styled = {},xpos = xpos) 
                            elif col > 0:
                                print(fmtx(fma,displaystr,spaces(2)),okcolcolors[col],styled = {})
                                if col == okcols.len - 1: echo()  
                            else: discard
                            
                            
                elif header == false and headertext != @[] :
                            if col == 0 :
                                print(fmtx(fma,displaystr,spaces(2)),okcolcolors[col],styled = {},xpos = xpos) 
                            elif col > 0:
                                print(fmtx(fma,displaystr,spaces(2)),okcolcolors[col],styled = {})
                                if col == okcols.len - 1: echo()  
                            else: discard
                            
                            
                  
                elif header == true and headertext == @[]:

                            if col == 0 and row == 0:
                                print(fmtx(fma,displaystr,spaces(2)),yellowgreen,styled = {styleunderscore},xpos = xpos)  
                            
                            elif col > 0 and row == 0:
                                print(fmtx(fma,displaystr,spaces(2)),yellowgreen,styled = {styleunderscore})                                   
                                if col == okcols.len - 1: echo()                      
                                
                            # all other rows data
                            elif col == 0 and row > 0:
                                print(fmtx(fma,displaystr,spaces(2)),okcolcolors[col],styled = {},xpos = xpos) 
                            elif col > 0 and row > 0:
                                print(fmtx(fma,displaystr,spaces(2)),okcolcolors[col],styled = {})
                                      
                                if col == okcols.len - 1:          
                                    echo()  
                            else: discard
           
                elif  header == true and headertext != @[] :
                            
                            if headerflagok == false:                   # print the header first    
                              
                                for hcol in 0.. <okcols.len:
                                    var nhcol = okcols[hcol] - 1
                                  
                                    var hcolfm = ""
                                    var hfma   = newSeq[string]()
                                    if leftalignflag == true:
                                          hcolfm = "<" & $(okcolwd[hcol])  # constructing the format string
                                    else:
                                          hcolfm = ">" & $(okcolwd[hcol])  # constructing the format string
                                    hfma = @[hcolfm,""]   
                                                                  
                                    if hcol == 0:
                                         print(fmtx(hfma,headertext[nhcol],spaces(2)),yellowgreen,styled = {styleunderscore},xpos = xpos) 
                                    elif hcol > 0:
                                         print(fmtx(hfma,headertext[nhcol],spaces(2)),yellowgreen,styled = {styleunderscore}) 
                                         if hcol == okcols.len - 1: 
                                            echo()    
                                            headerflagok = true            # set the flag as all headertext items printed
                            
                            if headerflagok == true:                       # all other rows data
                                if col == 0 and row >= 0  :
                                      print(fmtx(fma,displaystr,spaces(2)),okcolcolors[col],styled = {},xpos = xpos) 
                                elif col > 0 and row >= 0 :
                                      print(fmtx(fma,displaystr,spaces(2)),okcolcolors[col],styled = {})     
                                      if col == okcols.len - 1: echo()           
                                
                    
                       
          if frame == true:            
              
              if  header == false and headertext == @[] :
                      
                      if toplineflag == false:                              # set up topline of frame
                          print(".",yellow,xpos = xpos)
                          hline(frametoplinelen - 2 ,framecolor,xpos = xpos + 1,lt = hfct) 
                          printLn(".",lime)
                          toplineflag = true                                # set toplineflag , topline of frame ok
                      
                      if col == 0: 
                            print(framecolor & vfcs & okcolcolors[col] & fmtx(fma,displaystr,spaces(1) & framecolor & vfc & white),okcolcolors[col],styled = {},xpos = xpos)
                            if col == okcols.len - 1: echo()
                      else: # other cols of header
                            print(fmtx(fma,displaystr,spaces(1) & framecolor & vfc & white),okcolcolors[col],styled = {})  
                            if col == okcols.len - 1: echo() 
              
              
              elif  header == false and headertext != @[]:
                      
                      if toplineflag == false:                              # set up topline of frame
                          print(".",yellow,xpos = xpos)
                          hline(frametoplinelen - 2 ,framecolor,xpos = xpos + 1,lt = hfct) 
                          printLn(".",lime)
                          toplineflag = true                                # set toplineflag , topline of frame ok
                      
                      if col == 0: 
                            print(framecolor & vfcs & okcolcolors[col] & fmtx(fma,displaystr,spaces(1) & framecolor & vfc & white),okcolcolors[col],styled = {},xpos = xpos)
                            if col == okcols.len - 1: echo()
                      else: # other cols of header
                            print(fmtx(fma,displaystr,spaces(1) & framecolor & vfc & white),okcolcolors[col],styled = {})  
                            if col == okcols.len - 1: echo() 
              
              
              
              elif  header == true and headertext == @[]:                  # first line will be used as header
                      # set up topline of frame
                      if toplineflag == false:
                          print(".",magenta,xpos = xpos)
                          hline(frametoplinelen - 2 ,framecolor,xpos = xpos + 1,lt = hfct) 
                          printLn(".",lime)
                          toplineflag = true   
                        
                                              
                      # first row as header 
                      if col == 0 and row == 0:
                              print(framecolor & vfcs & yellowgreen & fmtx(fma,displaystr,spaces(1) & framecolor & vfc & white),yellowgreen,styled = {styleunderscore},xpos = xpos)                           
                              
                      elif col > 0 and row == 0:
                                  print(fmtx(fma,displaystr,spaces(1) & framecolor & vfc & white),yellowgreen,styled = {styleunderscore})  
                                  if col == okcols.len - 1: echo()                      
                                
                      # all other rows data
                      elif col == 0 and row > 0:
                                  print(framecolor & vfcs & okcolcolors[col] & fmtx(fma,displaystr,spaces(1) & framecolor & vfc & white),okcolcolors[col],styled = {},xpos = xpos)
                              
                      elif col > 0 and row > 0:
                                  print(fmtx(fma,displaystr,spaces(1) & framecolor & vfc & white),okcolcolors[col],styled = {}) 
                                  if col == okcols.len - 1: echo()  
                      else: discard
                
              elif  header == true and headertext != @[] :
                  
                            
                            if toplineflag == false:                            # set up topline of frame
                                print(".",magenta,xpos = xpos)
                                hline(frametoplinelen - 2 ,framecolor,xpos = xpos + 1,lt = hfct) 
                                printLn(".",lime)
                                toplineflag = true   
                        
                  
                            #print the header first
                            
                            if headerflagok == false:
                              
                                for hcol in 0.. <okcols.len:
                                    
                                    var nhcol = okcols[hcol] - 1
                                    if nhcol == -1:
                                         nhcol = 0
                                                                         
                                  
                                    var hcolfm = ""
                                    var hfma   = newSeq[string]()
                                    if leftalignflag == true:
                                          hcolfm = "<" & $(okcolwd[hcol])  # constructing the format string
                                    else:
                                          hcolfm = ">" & $(okcolwd[hcol])  # constructing the format string
                                    hfma = @[hcolfm,""]   
                                                                  
                                    if hcol == 0:
                                      print(framecolor & vfcs & yellowgreen & fmtx(hfma,headertext[nhcol],spaces(1) & framecolor & vfc & white),yellowgreen,styled = {styleunderscore},xpos = xpos) 
                                    elif hcol > 0:
                                      print(fmtx(hfma,headertext[nhcol],spaces(1) & framecolor & vfc & white),yellowgreen,styled = {styleunderscore}) 
                                      if hcol == okcols.len - 1: 
                                          echo()    
                                          headerflagok = true
                                          
                            
                            if headerflagok == true:   
                               # all other rows data
                              
                              if header == true: 
                                                              
                                if col == 0 and row >= 0  :
                                     print(framecolor & vfcs & okcolcolors[col] & fmtx(fma,displaystr,spaces(1) & framecolor & vfc & white),okcolcolors[col],styled = {},xpos = xpos) 
                                elif col > 0 and row >= 0 :
                                     print(fmtx(fma,displaystr,spaces(1) & framecolor & vfc & white),okcolcolors[col],styled = {})     
                                     if col == okcols.len - 1: echo()  
                              
        
          

          if row + 1 == okrows and col == okcols.len - 1  and bottomrowflag == false and frame == true:
                          # draw a bottom frame line  
                          print(".",lime,xpos = xpos)  # left dot
                          hline(frametoplinelen - 2 ,framecolor,xpos = xpos + 1,lt = hfcb) # hfx
                          printLn(".",lime)
                          bottomrowflag = true
          
    else :
      for brow in 0.. <okrows:   # note we get okrows data rows back and the header
        var row = brow       
        for col in 0.. <okcols.len:
       
            
          ncol = okcols[col] - 1
          if ncol < 0: ncol = 0
             
          try:                    
                displaystr = $df.df[row][ncol]  # will be cut to size by fma below to fit into colwd
          except IndexError:
                # if row data not available we put NA , the actual df column does not contain NA
                displaystr = "NA"
          
          var colfm = ""
          var fma   = newSeq[string]()
          if leftalignflag == true:
              colfm = "<" & $(okcolwd[col])  # constructing the format string
          else:
              colfm = ">" & $(okcolwd[col])  # constructing the format string
          fma = @[colfm,""]  
          
          # new setup 6 display options
          
          #noframe noheader           1 ok
          #noframe firstlineheader    2 ok   
          #noframe headertextheader   3 ok
          
          # ok for more than 1 col  
          #frame   noheader           4 ok
          #frame   firstlineheader    5 ok   
          #frame   headertextheader   6 ok
          
          if frame == false:
          
                if header == false and headertext == @[] :
                            if col == 0 :
                                print(fmtx(fma,displaystr,spaces(2)),okcolcolors[col],styled = {},xpos = xpos) 
                            elif col > 0:
                                print(fmtx(fma,displaystr,spaces(2)),okcolcolors[col],styled = {})
                                if col == okcols.len - 1: echo()  
                            else: discard
                            
                            
                elif header == false and headertext != @[] :
                            if col == 0 :
                                print(fmtx(fma,displaystr,spaces(2)),okcolcolors[col],styled = {},xpos = xpos) 
                            elif col > 0:
                                print(fmtx(fma,displaystr,spaces(2)),okcolcolors[col],styled = {})
                                if col == okcols.len - 1: echo()  
                            else: discard
                               
                  
                elif header == true and headertext == @[]:

                            if col == 0 and row == 0:
                                print(fmtx(fma,displaystr,spaces(2)),yellowgreen,styled = {styleunderscore},xpos = xpos)  
                            
                            elif col > 0 and row == 0:
                                print(fmtx(fma,displaystr,spaces(2)),yellowgreen,styled = {styleunderscore})                                   
                                if col == okcols.len - 1: echo()                      
                                
                            # all other rows data
                            elif col == 0 and row > 0:
                                print(fmtx(fma,displaystr,spaces(2)),okcolcolors[col],styled = {},xpos = xpos) 
                            elif col > 0 and row > 0:
                                print(fmtx(fma,displaystr,spaces(2)),okcolcolors[col],styled = {})
                                      
                                if col == okcols.len - 1:          
                                    echo()  
                            else: discard
           
                elif  header == true and headertext != @[] :
                            
                            if headerflagok == false:                   # print the header first    
                              
                                for hcol in 0.. <okcols.len:
                                    var nhcol = okcols[hcol] - 1
                                  
                                    var hcolfm = ""
                                    var hfma   = newSeq[string]()
                                    if leftalignflag == true:
                                          hcolfm = "<" & $(okcolwd[hcol])  # constructing the format string
                                    else:
                                          hcolfm = ">" & $(okcolwd[hcol])  # constructing the format string
                                    hfma = @[hcolfm,""]   
                                                                  
                                    if hcol == 0:
                                         print(fmtx(hfma,headertext[nhcol],spaces(2)),yellowgreen,styled = {styleunderscore},xpos = xpos) 
                                    elif hcol > 0:
                                         print(fmtx(hfma,headertext[nhcol],spaces(2)),yellowgreen,styled = {styleunderscore}) 
                                         if hcol == okcols.len - 1: 
                                            echo()    
                                            headerflagok = true            # set the flag as all headertext items printed
                            
                            if headerflagok == true:                       # all other rows data
                                if col == 0 and row >= 0  :
                                      print(fmtx(fma,displaystr,spaces(2)),okcolcolors[col],styled = {},xpos = xpos) 
                                elif col > 0 and row >= 0 :
                                      print(fmtx(fma,displaystr,spaces(2)),okcolcolors[col],styled = {})     
                                      if col == okcols.len - 1: echo()           
                                
                    
                       
          if frame == true:            
              
              if  header == false and headertext == @[] :
                      
                      if toplineflag == false:                              # set up topline of frame
                          print(".",yellow,xpos = xpos)
                          hline(frametoplinelen - 2 ,framecolor,xpos = xpos + 1,lt = hfct) 
                          printLn(".",lime)
                          toplineflag = true                                # set toplineflag , topline of frame ok
                      
                      if col == 0: 
                            print(framecolor & vfcs & okcolcolors[col] & fmtx(fma,displaystr,spaces(1) & framecolor & vfc & white),okcolcolors[col],styled = {},xpos = xpos)
                            if col == okcols.len - 1: echo()
                      else: # other cols of header
                            print(fmtx(fma,displaystr,spaces(1) & framecolor & vfc & white),okcolcolors[col],styled = {})  
                            if col == okcols.len - 1: echo() 
              
              
              elif  header == false and headertext != @[]:
                      
                      if toplineflag == false:                              # set up topline of frame
                          print(".",yellow,xpos = xpos)
                          hline(frametoplinelen - 2 ,framecolor,xpos = xpos + 1,lt = hfct) 
                          printLn(".",lime)
                          toplineflag = true                                # set toplineflag , topline of frame ok
                      
                      if col == 0: 
                            print(framecolor & vfcs & okcolcolors[col] & fmtx(fma,displaystr,spaces(1) & framecolor & vfc & white),okcolcolors[col],styled = {},xpos = xpos)
                            if col == okcols.len - 1: echo()
                      else: # other cols of header
                            print(fmtx(fma,displaystr,spaces(1) & framecolor & vfc & white),okcolcolors[col],styled = {})  
                            if col == okcols.len - 1: echo() 
              
              
              
              elif  header == true and headertext == @[]:                  # first line will be used as header
                      # set up topline of frame
                      if toplineflag == false:
                          print(".",magenta,xpos = xpos)
                          hline(frametoplinelen - 2 ,framecolor,xpos = xpos + 1,lt = hfct) 
                          printLn(".",lime)
                          toplineflag = true   
                        
                                              
                      # first row as header 
                      if col == 0 and row == 0:
                              print(framecolor & vfcs & yellowgreen & fmtx(fma,displaystr,spaces(1) & framecolor & vfc & white),yellowgreen,styled = {styleunderscore},xpos = xpos)                           
                              
                      elif col > 0 and row == 0:
                                  print(fmtx(fma,displaystr,spaces(1) & framecolor & vfc & white),yellowgreen,styled = {styleunderscore})  
                                  if col == okcols.len - 1: echo()                      
                                
                      # all other rows data
                      elif col == 0 and row > 0:
                                  print(framecolor & vfcs & okcolcolors[col] & fmtx(fma,displaystr,spaces(1) & framecolor & vfc & white),okcolcolors[col],styled = {},xpos = xpos)
                              
                      elif col > 0 and row > 0:
                                  print(fmtx(fma,displaystr,spaces(1) & framecolor & vfc & white),okcolcolors[col],styled = {}) 
                                  if col == okcols.len - 1: echo()  
                      else: discard
                
              elif  header == true and headertext != @[] :
                  
                            
                            if toplineflag == false:                            # set up topline of frame
                                print(".",magenta,xpos = xpos)
                                hline(frametoplinelen - 2 ,framecolor,xpos = xpos + 1,lt = hfct) 
                                printLn(".",lime)
                                toplineflag = true   
                        
                  
                            #print the header first
                            
                            if headerflagok == false:
                              
                                for hcol in 0.. <okcols.len:
                                    
                                    var nhcol = okcols[hcol] - 1
                                    if nhcol == -1:
                                         nhcol = 0
                                                                         
                                  
                                    var hcolfm = ""
                                    var hfma   = newSeq[string]()
                                    if leftalignflag == true:
                                          hcolfm = "<" & $(okcolwd[hcol])  # constructing the format string
                                    else:
                                          hcolfm = ">" & $(okcolwd[hcol])  # constructing the format string
                                    hfma = @[hcolfm,""]   
                                                                  
                                    if hcol == 0:
                                      print(framecolor & vfcs & yellowgreen & fmtx(hfma,headertext[nhcol],spaces(1) & framecolor & vfc & white),yellowgreen,styled = {styleunderscore},xpos = xpos) 
                                    elif hcol > 0:
                                      print(fmtx(hfma,headertext[nhcol],spaces(1) & framecolor & vfc & white),yellowgreen,styled = {styleunderscore}) 
                                      if hcol == okcols.len - 1: 
                                          echo()    
                                          headerflagok = true
                                          
                            
                            if headerflagok == true:   
                               # all other rows data
                              
                              if header == true: 
                                                              
                                if col == 0 and row >= 0  :
                                     print(framecolor & vfcs & okcolcolors[col] & fmtx(fma,displaystr,spaces(1) & framecolor & vfc & white),okcolcolors[col],styled = {},xpos = xpos) 
                                elif col > 0 and row >= 0 :
                                     print(fmtx(fma,displaystr,spaces(1) & framecolor & vfc & white),okcolcolors[col],styled = {})     
                                     if col == okcols.len - 1: echo()  
                              
        
          

          if row + 1 == okrows and col == okcols.len - 1  and bottomrowflag == false and frame == true:
                          # draw a bottom frame line  
                          print(".",lime,xpos = xpos)  # left dot
                          hline(frametoplinelen - 2 ,framecolor,xpos = xpos + 1,lt = hfcb) # hfx
                          printLn(".",lime)
                          bottomrowflag = true
          


proc showDataframeInfo*(df:nimdf) = 
   ## showDataframeInfo
   ## 
   ## some basic information of the dataframe
   ## 
   echo()
   hdx(printLn("Dataframe Inspection ",peru,styled = {}))
   showHeader(df)
   showCounts(df)
   echo()
   printLn("Display parameters   ",peru,xpos = 2)
   printLn("Colors         ( if any ) :",salmon,xpos = 2)
   printLn(df.colcolors,xpos = 2)
   printLn("Column Headers ( if any ) :",salmon,xpos = 2)
   printLn(df.colheaders,xpos = 2)
   printLn("Row Headers    ( if any ) :",salmon,xpos = 2)
   printLn(df.rowheaders,xpos = 2)
   printLn("Column widths  ( if any ) :",salmon,xpos = 2)
   printLn(df.colwidths,xpos = 2)
   
   echo()    
   
   hdx(printLn("End of dataframe inspection ", zippi,styled = {}))
   decho(1)


proc getColData*(df:nimdf,col:int):nimss =
     ## getColData
     ## 
     ## get one column from a nimdf dataframe
     ## 
     ## Note : col = 1 denotes first col of df , which is consistent with showDf 
     ##          
     ## 
     ## 
     
     var zcol = col - 1
     if zcol < 0 or zcol > df.colcount :
        printLn("Error : Wrong column number specified",red)
        quit(0)
     
     result = newNimSs()
     if df.hasHeader == false:
        for x in 0.. <df.df.len:
            try:
                result.add(df.df[x][zcol])    
            except IndexError:
                discard

     else:   # so there is a header in the first row
            
        for x in 1.. <df.df.len:     
            try:
                result.add(df.df[x][zcol])    
            except IndexError:
                discard

                
proc getRowDataRange*(df:nimdf,rows:nimis = @[] , cols:nimis = @[]) : nimdf =
  ## getRowDataRange
  ## 
  ## creates a new df with rows and cols as stipulated extracted from an exisiting df
  ## 
  ## if rows or cols not stipulated all rows will be brought in
  ## 
  ## Following example uses rows 1,2,4,6 and cols 1,2,3 from df ndf5 to create a new df
  ## 
  ## ..code-block:: nim
  ##   var ndf6 = getRowDataRange(ndf5,rows = @[1,2,4,6],cols = @[1,2,3])
  ## 
  var aresult = newNimDf()
  aresult.hasHeader = df.hasHeader
  aresult.colcount = cols.len
  aresult.rowcount = rows.len
  
  
  var b = newNimSs()
  
  var arows = rows
  var acols = cols
  
  if arows.len == 0:
     arows = toSeq(0 .. <df.rowcount)
        
        
  if acols.len == 0:
     acols = toSeq(0 .. <df.colcount)
  
  # we extract named rows and cols from a df and create a new df
  for row in 0.. <arows.len:     
     for col in 0.. <acols.len:
         b.add(df.df[arows[row]][acols[col] - 1])       
     aresult.df.add(b) 
     b = @[]   
  result = aresult
 

proc `$`[T](some:typedesc[T]): string = name(T)
proc typetest[T](x:T): T =
  # used to determine the field types in the temp sqllite table used for sorting
  # note these procs are used only locally a generic typetest exists in cx
  
  #echo "type: ", type(x), ", value: ", x
  var cvflag = false
  intflag    = false
  floatflag  = false
  stringflag = false
    
  if cvflag == false and floatflag == false and intflag == false and stringflag == false:
    try:
       var i1 =  parseInt(x)
       if $type(i1) == "int":
          intflag = true
          #printLnBiCol("Intflag = true : " & $x )
          cvflag = true
    except ValueError:
          discard
    
  if cvflag == false and floatflag == false and intflag == false and stringflag == false:
   try:
      var f1 = parseFloat(x)
    
      if $type(f1) == "float":
         floatflag = true 
         #printLnBiCol("Floatflag = true : " & $x )
         cvflag = true
   except ValueError:
          discard
         

  if cvflag == false and intflag == false and floatflag == false and stringflag == false:
        try:
          # as all incoming are strings this will never fail and is put last here
          if $type(x) == "string":
             stringflag = true 
             #printLnBiCol("Stringflag = true : " & $x )
             cvflag = true
        except ValueError:
             discard 
 
  result = $type(x)   


proc sortdf*(df:nimdf,sortcol:int = 1,sortorder = asc):nimdf =
  ## sortdf
  ## 
  ## sorts a dataframe asc or desc 
  ## 
  ## supported sort types are integer ,float or string columns
  ## 
  ## other types maybe added later
  ## 
  ## the idea implemented here is to read the df into a temp sqllite table
  ## sort it and return the sorted output as nimdf
  ## 
  ##  .. code-block:: nim
  ##  
  ##     var ndf2 = sortdf(ndf,5,"asc")  $ sort a dataframe on the fifth col ascending
  ##  
  ## Note : data columns passed in must be correct for all rows , that is rows with different column count will result in errors
  ##        this will be addressed in future versions
  ##     

  var asortcol = sortcol
  #let db = open("localhost", "user", "password", "dbname")
  let db = open(":memory:", nil, nil, nil)
  db.exec(sql"DROP TABLE IF EXISTS dfTable")
  var createstring = "CREATE TABLE dfTable (Id INTEGER PRIMARY KEY "
  for x in 0.. <df.colcount:
       discard typetest(df.df[1][x])   # here we do the type testing for table creation
       
       if intflag == true:
          createstring = createstring & "," & $char(x + 65) & " integer "   
      
       elif floatflag == true:
          createstring = createstring & "," & $char(x + 65) & " float "  
      
       elif stringflag == true:
          createstring = createstring & "," & $char(x + 65) & " varchar(50) "
    
  createstring = createstring & ")"
  db.exec(sql"BEGIN")
  db.exec(sql(createstring))

  # now the table exists and we add data
  var insql = "INSERT INTO dfTable (" 
  var tabl = ""
  var vals = ""

  # set up the cols of the insert sql 
  for col in 0.. <df.colcount:
        if col < df.colcount - 1:
          tabl = tabl & $char(col + 65) & ","       
        else:   
          tabl = tabl & $char(col + 65)

  # set up the values of the insert sql   
  for row in 0.. <df.rowcount :
      for col in 0.. <df.colcount:
       try: 
         if typetest(df.df[row][col]) == "string":
        
            if col < df.colcount - 1:
              vals = vals & dbQuote(df.df[row][col]) & ","
              
            else:   
              vals = vals & dbQuote(df.df[row][col])
              
         elif typetest(df.df[row][col]) == "integer":
           
            if col < df.colcount - 1:
              vals = vals & df.df[row][col] & ","
            else:   
              vals = vals & df.df[row][col]
              
         elif typetest(df.df[row][col]) == "float":
           
            if col < df.colcount - 1:
              vals = vals & df.df[row][col] & ","
            else:   
              vals = vals & df.df[row][col]
       
       except IndexError:
              printLn("Error : Sorting of dataframe with columns of different row count currently only possible",red)
              printLn("        if the column with the least rows is the first column of the dataframe",red)
              echo()
              discard
              #raise
              
       
      insql = insql & tabl & ") VALUES (" & vals & ")"   # the insert sql
      #echo insql
      
      try:
        db.exec(sql(insql))
      except DbError,IndexError:
        #echo insql
        discard
        
      insql = "INSERT INTO dfTable (" 
      vals = ""  
   
  db.exec(sql"COMMIT")    
  
  var filename =  "nimDftempData.csv"
  var  data2 = newFileStream(filename, fmWrite) 
  if asortcol - 1 < 1: asortcol = 1
  var sortcolname = $chr(64 + asortcol) 
  var selsql = "select * from dfTable ORDER BY" & spaces(1) & sortcolname & spaces(1) & sortorder 
  for dbrow in db.fastRows(sql(selsql)) :
     for x in 1.. <dbrow.len - 1:    
        data2.write(dbrow[x] & ",")
     data2.writeLine(dbrow[dbrow.len - 1])
  data2.close()
  db.exec(sql"DROP TABLE IF EXISTS dfTable")
  db.close()
  #prepare for output
  var df2 =  createDataFrame(filename = filename,cols = df.df[0].len,hasHeader = df.hasHeader)
  removeFile(filename)
  result = df2


proc makeNimDf*(dfcols : varargs[nimss],hasHeader:bool = false):nimdf = 
  ## makeNimDf
  ## 
  ## creates a nimdf with passed in col data which is of type nimss
  ## 
  #  TODO  will need to check if all cols are same length otherwise append  NaN etc
  # 
  var df = newNimDf()
  for x in dfcols: df.df.add(x)
  result = makeDf2(df,hasheader = hasHeader)


proc createDataFrame*(filename:string,cols:int = 2,rows:int = -1,sep:char = ',',hasHeader:bool = false):nimdf = 
  ## createDataFrame
  ## 
  ## attempts to create a nimdf dataframe from url or local path
  ## 
  ## prefered are comma delimited csv or txt files
  ## 
  ## other should be clean , preprocess as needed
  ## 
  ## 
  
  printLn("Processing ...",skyblue) 
  curup(1)
  
  if filename.startswith("http") == true:
      var data1 = getData1(filename)
      result = makeDf1(data1,hasHeader = hasHeader)
  else:
      var data2 = getdata2(filename = filename,cols = cols,rows = rows,sep = sep)  
      result = makeDf2(data2,cols,hasHeader)

  printLn(clearline)
  

  
proc createBinaryTestData*(filename:string = "nimDfBinaryTestData.csv",datarows:int = 2000,withHeaders:bool = false) = 

  var  data = newFileStream(filename, fmWrite)
  # cols,colwd parameters seqs must be of equal length
  var cols      = @[1,2,3,4,5,6,7,8]
  var colwd     = @[2,2,2,2,2,2,2,2]
  
  
  if withHeaders == true:
     var headers   = @["A"]
     for x in 66.. 90: headers.add($char(x)) 
     for dx in 0.. <cols.len - 1: data.write(headers[dx] & ",")  
     data.writeLine(headers[cols.len - 1])
  
  
  for dx in 0.. <datarows:
      for cy in 0.. <cols.len - 1:
          data.write($getRndInt(0,1) & ",")
      data.writeLine($getRndInt(0,1))
  data.close()
  printLn("Created test data file : " & filename )  
  
  
proc createRandomTestData*(filename:string = "nimDfTestData.csv",datarows:int = 2000,withHeaders:bool = false) =
  ## createRandomTestData
  ##
  ## a file will be created in current working directory
  ## 
  ## default name nimDfTestData.csv or as given
  ## 
  ## default columns 8 
  ## default rows 2000
  ## default headers none
  ## 
  ## 
  
  
  var  data = newFileStream(filename, fmWrite)
  
  # cols,colwd parameters seqs must be of equal length
  var cols      = @[1,2,3,4,5,6,7,8]
  var colwd     = @[10,10,10,10,10,10,14,10]
  
  
  if withHeaders == true:
     var headers = @["A"]
     for x in 66 .. 90: headers.add($char(x)) 
     for dx in 0 .. <cols.len - 1: data.write(headers[dx] & ",")  
     data.writeLine(headers[cols.len - 1])
  
  
  for dx in 0.. <datarows:
       
      data.write(getRndDate() & ",")
      data.write($getRndInt(0,100000) & ",")
      data.write($getRndInt(0,100000) & ",")
      data.write(newWord(3,8) & ",")
      data.write(ff(getRndFloat() * 345243.132310 * getRandomSignF(),2) & ",")
      data.write(newWord(3,8) & ",")
      data.write($getRndBool() & ",")
      data.writeLine($getRndInt(0,100))
  
  data.close()
  printLn("Created test data file : " & filename )  
  

proc dfRowStats*(df:nimdf,row:int):Runningstat =
   # sumStats
   # 
   # calculates statistics for numeric rows and returns a Runningstat instance
   # 
   
   var psdata = newSeq[Runningstat]()
   var ps : Runningstat
   for col in 0 .. <toNimis(toSeq(0 .. <df.colcount)).len:
           try:
              ps.push(parsefloat(df.df[row][col]))
              psdata.add(ps)
           except:
              discard   # rough, we discard any parsefloat errors due to na or text column etc
   result = ps
  
  
  
  
proc dfColumnStats*(df:nimdf,colseq:seq[int]): seq[Runningstat] =
        ## dfColumnStats
        ## 
        ## returns a seq[Runningstat] for all columns specified in colseq for dataframe df
        ## 
        ## so if colSeq = @[1,3,6] , we would get stats for cols 1,3,6
        ## 
        ## see nimdfT11.nim  for an example
        ## 
        
        var psdata = newSeq[Runningstat]()
        for x in colseq:
           var coldata = getColData(df,x)
           var ps : Runningstat
           ps.clear()
           for xx in coldata:
              try:
                 var xxx =  parsefloat(xx.strip())
                 ps.push(xxx)
              except ValueError:
                 discard
           psdata.add(ps)      
        result = psdata

        

proc dfShowColumnStats*(df:nimdf,desiredcols:seq[int],colspace:int = 25,xpos:int = 1) =
  ## dfShowColumnStats
  ## 
  ## shows output from dfColumnStats
  ## 
  ## TODO: check for headers in first line to avoid crashes
  ##       assert that column data is Somenumber type or have an automatic selector for anything numeric
  ## 
  ## xpos the starting display position
  ## colspace allows to nudge the distance between the displayed column statistics
  ## 
  printLn("Dataframe Column Statistics\n",peru,xpos = 2)
  
  # check that desiredcols is not more than available in df to avoid indexerrors etc later
  # we just cut off the right most entry of desiredcols until it fits
  let cc = df.colcount
  var ddesiredcols = desiredcols
  while  ddesiredcols.len > cc:  ddesiredcols.delete(ddesiredcols.len - 1)
    
      
  var mydfstats = dfColumnStats(df,ddesiredcols)
  var nxpos = xpos

     
  for x in 0..<mydfstats.len:
      # if there are many columns we try to display grid wise
      if nxpos > tw - 22:
        curdn(20)
        nxpos = xpos
  
      printLnBiCol("Column : " & $(ddesiredcols[x]) & " Statistics",xpos = nxpos,styled={styleUnderscore})
      showStats(mydfstats[x],xpos = nxpos) 
      nxpos += colspace
      curup(15)
      
  curdn(20) 
  if df.hasheader == true:
    printLnBiCol(" hasHeader : " & $df.hasHeader,xpos = 1)
    printLnBiCol(" Processed " & dodgerblue & "->" & yellowgreen & " Rows : " & $(df.rowcount - 1),xpos = 1)
  else: 
    printLnBiCol(" hasHeader :" & $df.hasHeader,xpos = 1)
    printLnBiCol(" Processed " & dodgerblue & "->" & yellowgreen & " Rows : " & $df.rowcount,xpos = 1)
    
  printLnBiCol(" Processed " & dodgerblue & "->" & yellowgreen & " Cols : " & $ddesiredcols.len & " of " & $df.colcount,xpos = 1)



proc sumStats*(df:nimdf,numericCols:nimis):Runningstat =
   # sumStats
   # 
   # calculates statistics for numeric columns sums
   # 
   let mydfstats = dfColumnStats(df,numericCols)
   var psdata = newSeq[Runningstat]()
   var ps : Runningstat
   for x in 0 .. <mydfstats.len:
           ps.push(float(mydfstats[x].sum))
           psdata.add(ps) 
   result = ps
   
  
proc dfShowSumStats*(df:nimdf,numericCols:nimis,xpos = 2) =
     ## showSumStats
     ## 
     ## shows a statistic for all column sums
     ## 
     ## maybe usefull if a dataframe has many columns where there is a need to know the 
     ## 
     ## total sum of all numeric columns and relevant statistics of the resulting sums row
     ## 
     echo()
     printLn("Dataframe Statistics for Column Sums  -- > Sum is the Total of columns sum statistic\n",peru,xpos = xpos)  
     showStats(sumStats(df,numericCols),xpos = xpos)
     printLnBiCol(" Processed Sums " & dodgerblue & "->" & yellowgreen & " Rows : " & $1,xpos = 1)
     printLnBiCol(" Processed      " & dodgerblue & "->" & yellowgreen & " Cols : " & $numericCols.len & " of " & $df.colcount,xpos = 1)
     echo()  
  
  
  
  
proc dfSave*(df:nimdf,filename:string) = 
     ## dfSave
     ## 
     ## save a dataframe to a csv file 
     ## 
     ## Note if data is not clean crashes may occure if compiled with  -d:release 
     ##
  
     var rowcounter1 = newCxcounter()
     var totalcolscounter1 = newCxcounter()
     var errorcounter1 = newCxcounter()
     var errCount = 0
     var errFlag:bool = false
     var data = newFileStream(filename, fmWrite)
     var errorrows = newNimIs()
     
     for row in 0 .. <df.rowcount:
        if df.df[row].len < df.colcount:
              errorrows.add(row)
        for col in  0.. <df.colcount:
             try:
                if col <= df.colcount - 2 : 
                    data.write(df.df[row][col] & ",")
                else : 
                    data.writeLine(df.df[row][col])
                totalcolscounter1.add
             except IndexError  :
                errorcounter1.add
                discard
      
        rowcounter1.add
        
     data.close()
     echo()
     printLnBiCol("Dataframe saved to   : " & filename,xpos = 2)
     printLnBiCol("Rows written         : " & $rowcounter1.value,xpos = 2)
     printLnBiCol("Errors count         : " & $errorcounter1.value,xpos = 2) 
     printLnBiCol("Error rows           : " & wordwrap($errorrows,newLine = "\x0D\x0A" & spaces(25)),xpos = 2)  # align seq printout
     printLnBiCol("Expected Total Cells : " & $(df.colcount * df.rowcount),xpos = 2)     # cell is one data element of a row
     printLnBiCol("Actual Total Cells   : " & $totalcolscounter1.value,xpos = 2)
     if  df.colcount * df.rowcount <> totalcolscounter1.value:
         printLnBiCol("Saved status         : Saved with row errors. Original data may need preprocessing",yellowgreen,red,":",2,false,{})
     else:
         printLnBiCol("Saved status         : ok",xpos = 2)
     echo()
