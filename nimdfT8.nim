import nimcx,nimdataframe,algorithm

#  nimdfT8.nim
#  
#  Tests for nimdataframe
# 
#  shows usage of nimdataframe with test data created with gendata.py  from bluenotes nim dataframe
#  we actually get 2000 random rows out of above test data and run our tests with this data ....
#  
#  2017-05-02
#  


var data = "supported_tickers.csv"   
let displayrows = 8              # header row is counted as row to display
 
var ndf:nimdf                    # define a nim dataframe
 
ndf = createDataFrame(data,cols = 6)  # specify desired cols as per data file , default = 2 
printLnBiCol("Data Source : " & data)

# display various configurations of this df
showDf(ndf, rows = displayrows,cols = @[1,2,3,4,5,6],colwd = @[10,10,10,8,10,10], colcolors = @[pastelgreen,pastelpink],showframe = true,framecolor = goldenrod,showHeader = true,leftalignflag = false) 
echo()
showDataframeInfo(ndf)

var ndf2 = sortdf(ndf,5,"asc")   #<--- note the actual header disappears this needs to be considered
showDf(ndf2, rows = displayrows,cols = @[1,2,3,4,5,6],colwd = @[10,10,10,8,10,10], colcolors = @[pastelgreen,pastelpink],showframe = true,framecolor = goldenrod,showHeader = true,leftalignflag = false) 
echo()
showDataframeInfo(ndf2)


doFinish()
