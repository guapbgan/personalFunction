<%@page contentType="application/json" pageEncoding="UTF-8"%>
<%!
    //class
    ////Exception
    public class ValidErrorException extends RuntimeException{
        public String message;
        public ValidErrorException(String message){
            this.message = message;
        }

        @Override
        public String getMessage(){
            return message;
        }
    }
    public class UploadWarningException extends RuntimeException{
        public String message;
        public UploadWarningException(String message){
            this.message = message;
        }

        @Override
        public String getMessage(){
            return this.message;
        }
    }
    public class SqlDateTransformerException extends RuntimeException{
        public String message;
        public SqlDateTransformerException(String message){
            this.message = message;
        }

        @Override
        public String getMessage(){
            return this.message;
        }
    }
    ////Other
    public class RequestHolder{
        //  2019/11/29 version
        //
        //  Transfer request to map according to type of request. 
        //  If request is multipart/form-data, the upload file would be assign to fileIten(if existed).
        //  *Only support one file upload
        //
        //  field: requestMap, fileItem
        //  method: saveFile
        private Map<String, String> requestMap;
        private FileItem fileItem;

        public Map<String, String> getRequestMap(){
            return this.requestMap;
        }
        public RequestHolder(HttpServletRequest request) throws Exception{
            boolean isMultipart = ServletFileUpload.isMultipartContent(request);
            this.requestMap = new HashMap();
            if(isMultipart){
                // Create a factory for disk-based file items
                FileItemFactory factory = new DiskFileItemFactory();

                // Create a new file upload handler
                ServletFileUpload upload = new ServletFileUpload(factory);

                List items = upload.parseRequest(request);
                Iterator iter = items.iterator();
                while (iter.hasNext()) {
                    FileItem item = (FileItem) iter.next();
                    if(!item.isFormField()) {
                        //file slot
                        String originalFileName = item.getName();
                        if(originalFileName.equals("")){
                            //No upload file
                            continue;
                        }else{
                            this.fileItem = item;
                        }
                    }else{
                        //not file slot, get form data
                        String fieldName = item.getFieldName().trim();
                        String fieldValue = item.getString("UTF-8").trim();
                        this.requestMap.put(fieldName, fieldValue);
                    }
                }
                
            }else{
                for(Object o: request.getParameterMap().entrySet()){
                    Map.Entry<String, String[]> entry = (Map.Entry) o;
                    //request.getParameterMap() will return Map<String, String[]>
                    this.requestMap.put(entry.getKey(), entry.getValue()[0].trim());
                }
            }            
        }
        private String saveFile(boolean essential, String savePath, String fileName, long sizeLimit, String[] availableFileType) throws Exception{
            //  this will return file name which be saved successful
            //
            //  essential: file is necessary or not
            //  savePath: target folder
            //  sizeLimit: unit of sizeLimit is byte
            //  fileName: keep fileName = "" to use original file name, or use fileName which is input
            //  availableFileType: avaliable file type
            if(essential && this.fileItem == null){
                throw new UploadWarningException("no file");
            }else if(this.fileItem != null){
                if(this.fileItem.getSize() < sizeLimit){
                    String mainFileName, fileType;
                    String originalFileName = this.fileItem.getName();
                    
                    //get file name and file type
                    if(fileName.equals("")){
                        mainFileName = originalFileName.substring(0,originalFileName.lastIndexOf("."));
                    }else{
                        mainFileName = fileName;
                    }
                    fileType = originalFileName.substring(originalFileName.lastIndexOf(".")+1).toLowerCase();
                    
                    //check file type
                    Map availableMap = new HashMap();
                    for(String type: availableFileType){
                        availableMap.put(type,type);
                    }
                    if(availableMap.get(fileType) == null){
                        new UploadWarningException(fileType + " is not available");
                    }

                    //start upload
                    try {
                        //prevent duplicated file name replace existed file
                        int count = 0;
                        String newMainFileName = mainFileName;
                        while(true){
                            if(new File(savePath, newMainFileName + "." + fileType).exists()){
                                count++;
                                newMainFileName = String.format("%s (%d)", mainFileName, count);
                            }else{
                                break;
                            }
                        }
   
                        //upload file
                        this.fileItem.write(new File(savePath, newMainFileName + "." + fileType));
                        return newMainFileName + "." + fileType;
                    } catch (Exception e) {
                        throw e;
                    }                
                }else{
                    throw new UploadWarningException("file size could not be large than " + sizeLimit + " bytes");
                }                
            }else{
                return "";
            }
        }
    }
%>
<%!
    //function
    ////date
    public <T> T sqlDateTransformer(String sqlDatetimeString, Class<T> typeKey, String targetFormat) throws Exception{
        //  Input database date string and transfer it to the class assigned.
        //  *When target class is String, this will return "" if databaseDatetimeString = ""
        //
        //  databaseDatetimeString: raw string of timestamp from oracle database.  ex. "yyyy-MM-dd HH:mm:ss.S"
        //  typeKey: accept String.class, Date.class, Calender.class
        //  targetFormat: available when typeKey is String, and it could assign format of output string.   ex. "yyyy/MM/dd" -> "2019/11/20"
        if(typeKey == Date.class || typeKey == Calendar.class || typeKey == String.class){
            SimpleDateFormat sqlDatetimeFormat = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss.S");
            if(typeKey == Date.class){
                return typeKey.cast(sqlDatetimeFormat.parse(sqlDatetimeString));
            }else if(typeKey == String.class){
                if(!sqlDatetimeString.equals("")){
                    return typeKey.cast(new SimpleDateFormat(targetFormat).format(sqlDatetimeFormat.parse(sqlDatetimeString)));
                }else{
                    return typeKey.cast("");
                }     
            }else{
                Calendar calendar=Calendar.getInstance();
                calendar.setTime(sqlDatetimeFormat.parse(sqlDatetimeString));
                return typeKey.cast(calendar);
            }
        }else{
            throw new SqlDateTransformerException(String.format("typeKey error: %s does not allow", typeKey.toString()));
        }
    } 
    public <T> T sqlDateTransformer(String sqlDatetimeString, Class<T> typeKey) throws Exception{
        return typeKey.cast(sqlDateTransformer(sqlDatetimeString, typeKey, ""));
    }
    ////string
    public String fillChar(String oldString, int len, String padding){
        int gap = len - oldString.length();
        if(gap > 0){
            return new String(new char[gap]).replace("\0", padding) + oldString;
        }
        return oldString;
    }    

    public String concatenation(String[] stringArray){
        StringBuilder stringBuilder = new StringBuilder();
        for(String string: stringArray){
            stringBuilder.append(string);
        }
        return stringBuilder.toString();
    }
    ////html
    public String buildHtmlTablePart(String partElement, String[] stringArr){
        //  2019/11/26 version
        //  preset command must in this order: 
        //      1st: th -> set this cell is th element
        //      2nd: cs -> set colspan
        //      3rd: rs -> set rowspan
        //      4th: true or false -> to control that this cell should show or not
        //      then the command is followed by \\: and cell content which actually showing
        //      ex. thcs2rs2true\\:Price
        Pattern initPattern = Pattern.compile("(?<th>th)?(?<colspan>cs(?<colspanNum>\\d+))?(?<rowspan>rs(?<rowspanNum>\\d+))?(?<show>(true)|(false))?\\\\:(?<content>.*)");
        String headPartElement = "", rearPartElement = "";
        if(!partElement.equals("")){
            headPartElement = "<" + partElement + ">";
            rearPartElement = "</" + partElement + ">";
        }
        StringBuilder stringBuilder = new StringBuilder().append(headPartElement + "<tr>");

        for(int i = 0; i < stringArr.length; i++){
            Matcher initMatcher = initPattern.matcher(stringArr[i]);
            String cellTag = "td";
            if(initMatcher.find()){
                if(initMatcher.group("show") != null){
                    if(initMatcher.group("show").equals("false")){
                        continue;
                    }
                }
                if(initMatcher.group("th") != null){
                    cellTag = "th";
                }
                if(initMatcher.group("colspan") != null){ //column span
                    cellTag += " colspan='" + initMatcher.group("colspanNum") + "'";
                }
                if(initMatcher.group("rowspan") != null){
                    cellTag += " rowspan='" + initMatcher.group("rowspanNum") + "'";
                }
                stringBuilder.append("<").append(cellTag).append(">").append(initMatcher.group("content")).append("</").append(cellTag).append(">");
            }else if(stringArr[i].equals("\\n")){
                if(i < stringArr.length - 1){
                    stringBuilder.append("</tr><tr>");
                }else{
                    stringBuilder.append("</tr>" + rearPartElement);
                }
            }else{
                stringBuilder.append("<").append(cellTag).append(">").append(stringArr[i]).append("</").append(cellTag).append(">");
            }      
        }
        return stringBuilder.toString();
    }
    public String getTimeHtmlOption(double startHour, double endHour, double hourInterval){
        String outputString = "";
        DecimalFormat formatter = new DecimalFormat("00");
        for(double i = startHour; i < endHour + 1; i = i + hourInterval){
            String hour = formatter.format(Math.floor(i));
            String minu = formatter.format(i * 60 % 60);
            outputString = concatenation(new String[]{outputString, 
                "<option value='", hour, ":", minu, "'>", hour, ":", minu, "</option>"
            });
        }
        return outputString;
    }
    public String turnMapToHtmlOption(Map map){ //depend on concatenation()
        String outputString = "";
        for(Object object: map.entrySet()){
            Map.Entry<String, String> entry = (Map.Entry)object;
            outputString = concatenation(
                new String[]{outputString, "<option value='", entry.getKey(), "'>", entry.getValue(), "</option>"}
            );
        }
        return outputString;
    }
    //databese
    public List queryListContentJsonObj(List queryResult){
        List content = new ArrayList();
        if(queryResult.size() != 0){
            Iterator iterator = queryResult.iterator();
            while(iterator.hasNext()){
                Map map = (Map)iterator.next();
                map = replaceNullWithEmptyString(map);
                content.add(new JSONObject(map));
            }
        }
        return content;
    }
    public List<Map<String, String>> replaceNullWithEmptyString(List queryResult){
        List content = new ArrayList();
        if(queryResult.size() != 0){
            Iterator iterator = queryResult.iterator();
            while(iterator.hasNext()){
                Map<String, String> map = (Map)iterator.next();
                map = replaceNullWithEmptyString(map);
                content.add(map);
            }
        }
        return content;
    }    
    public Map<String, String> replaceNullWithEmptyString(Map oldMap){
        Map<String, String> newMap = new HashMap();
        for(Object object: oldMap.entrySet()){
            Map.Entry<String, String> entry = (Map.Entry)object;
            if(entry.getValue() == null){
                newMap.put(entry.getKey(), "");
            }else{
                newMap.put(entry.getKey(), ((Object)entry.getValue()).toString());
            }
        }
        return newMap;
    }    
    //other    
    public List<Integer> stringArrToIntList(String[] stringArr){
        List<Integer> integerList = new ArrayList();
        for(String string: stringArr){
            integerList.add(Integer.parseInt(string));
        }
        return integerList;
    }
    public Map<String, String> trimAndTransToUsefulMap(Map requestMap){
        Map<String, String> newDataMap = new HashMap();
        for(Object o: requestMap.entrySet()){
            Map.Entry<String, String[]> entry = (Map.Entry) o;
            newDataMap.put(entry.getKey(), entry.getValue()[0].trim());
        }
        return newDataMap;
    }    

%>
<%!
    //validation function for reference
    //2019/11/26
    public void valid_checkRequestParameter(Map<String, String> requestMap, String[] parameterNameArr){
        for(String parameter: parameterNameArr){
            if(requestMap.get(parameter).equals("")){
                throw new ValidErrorException("required parameter does not exist in request: " + parameter);
            }
        }
    }    
%>
<%@page import="java.util.*"%>
<%@page import="java.lang.RuntimeException"%>
<%@page import="java.text.SimpleDateFormat"%>
<%@page import="java.text.DecimalFormat"%>
<%@page import="java.lang.RuntimeException"%>
<%@page import="java.util.regex.Matcher"%>
<%@page import="java.util.regex.Pattern"%>
<%@page import="org.springframework.jdbc.core.JdbcTemplate"%>
<%@page import="org.springframework.web.context.support.WebApplicationContextUtils"%>
<%@page import="org.springframework.context.ApplicationContext"%>
<%@page import="org.springframework.transaction.PlatformTransactionManager" %>
<%@page import="org.springframework.transaction.TransactionDefinition" %>
<%@page import="org.springframework.transaction.TransactionStatus" %>
<%@page import="org.springframework.transaction.support.DefaultTransactionDefinition" %>
<%@page import="java.math.BigDecimal"%>
<%@page import="org.json.JSONArray"%>
<%@page import="org.json.JSONObject"%>
<%@ page import="org.apache.commons.fileupload.*"%>
<%@ page import="org.apache.commons.fileupload.disk.DiskFileItemFactory"%>
<%@ page import="org.apache.commons.fileupload.servlet.ServletFileUpload"%>
<%@ page import="java.io.File"%>