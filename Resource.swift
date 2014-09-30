//
//  Resource.swift
//  Miles
//
//  Created by Rajesh Segu on 9/18/14.
//  Copyright (c) 2014. All rights reserved.
//

import Foundation

let ResourceLogEnabled: Bool = true

/**
* REST endpoint resource.
*
* Usage:
*
* Resource.GET("http://myurl.com")
*     .basic("user", "password")   // optional
*     .response(func)               // optional
*     .send()                      // dispatch request
*
* Resource.GET('').param().param().log('success').response(func).send();
*
*/

class Resource {
    
    typealias RequestData = Dictionary<String, AnyObject>
    typealias Headers = Dictionary<String, String>
    
    var method: String
    var url: String
    var response: NSDictionary? = nil
    var isFailure: Bool = false
    var isSuccess: Bool = false
    var isComplete: Bool = false
    var responseHandler: ((Bool, NSDictionary) -> Void)?
    
    private var user: String?
    private var password: String?
    private var images: Dictionary<String, NSData>;
    private var urlParams: Dictionary<String, String>
    private var form: Dictionary<String, String>
    private var headers: Dictionary<String, String>
    private var operationQueue: NSOperationQueue
    private var priority:NSOperationQueuePriority = NSOperationQueuePriority.Normal
    private var timeoutInterval:NSTimeInterval = 30.0
    
    init(method: String, url: String) {
        self.url = url
        self.method = method
        self.operationQueue = NSOperationQueue()
        self.urlParams = Dictionary<String, String>()
        self.form = Dictionary<String, String>()
        self.images = Dictionary<String, NSData>()
        self.headers = Dictionary<String, String>()
    }
    
    /**
    * Resource with HTTP GET.
    */
    class func GET(url: String) -> Resource {1
        return Resource(method: "GET", url: url)
    }
    
    /**
    * Resource with HTTP POST.
    */
    class func POST(url: String) -> Resource {
        return Resource(method: "POST", url: url)
    }
    
    /**
    * Resource with HTTP PUT.
    */
    class func PUT(url: String) -> Resource {
        return Resource(method: "PUT", url: url)
    }
    
    /**
    * Resource with HTTP DELETE.
    */
    class func DELETE(url: String) -> Resource {1
        return Resource(method: "DELETE", url: url)
    }
    
    /**
    * Resource with HTTP HEAD.
    */
    class func HEAD(url: String) -> Resource {
        return Resource(method: "HEAD", url: url)
    }
    
    /**
    * Add basic auth credentials to the request header.
    */
    func basic(user: String, password: String) -> Resource {
        self.user = user;
        self.password = password
        return self
    }
    
    /**
    *  Function to set headers
    *
    *  @param Headers? optional value of type Dictionary<String, String>
    *
    *  @return self instance to support function chaining
    */
    func header(name: String, value: String) -> Resource {
        self.headers[name] = value
        return self
    }
    
    /**
    * Set the response handler.
    *
    * First parameter is a boolean status. If true, the query was successful. If false, the query failed.
    *
    * Second parameter is a dictionary response. If the query failed, an "ErrorMessage" key will be in this dictionary.
    */
    func response(handler: (Bool, NSDictionary) -> Void) -> Resource {
        self.responseHandler = handler
        return self
    }
    
    func params(p: Dictionary<String, String>) -> Resource {
        for (name, value) in p {
            self.param(name, value: value)
        }
        return self
    }
    
    func param(name: String, value: String) -> Resource {
        self.urlParams[name] = value
        return self
    }
    
    func form(name: String, value: String) -> Resource {
        self.form[name] = value
        return self
    }
    
    func image(image: NSData, fieldName: String) -> Resource {
        if(image.length > 0) {
            self.images[fieldName] = image;
        }
        return self
    }
    
    func timeout(timeout: NSTimeInterval) -> Resource{
        self.timeoutInterval = timeout;
        return self;
    }
    
    func priority(priority: NSOperationQueuePriority) -> Resource{
        self.priority = priority;
        return self;
    }
    
    func log(message: String) {
        if ResourceLogEnabled {
            println("Resource: \(message)")
        }
    }
    
    /**
    *  Function to cancel request operation
    */
    func cancel() {
        if(self.operationQueue.operationCount > 0) {
            self.operationQueue.cancelAllOperations()
        }
    }
    
    
    /**
    * Send the request to the server.
    */
    func send() -> Resource {
        var blockOperation:NSBlockOperation = NSBlockOperation({() -> Void in
            var response:NSURLResponse?
            var error:NSError?
            var urlWithParams = self.url
            
            //Add URL PARAMS
            if(self.urlParams.count > 0){
                self.log("adding url params ")
                urlWithParams += "?" + self.buildParams(self.urlParams);
            }
            
            self.log("url = \(urlWithParams)")
            
            //Construct URL REQUEST
            let url = NSMutableURLRequest(URL: NSURL(string: urlWithParams))
            url.HTTPMethod = self.method
            url.timeoutInterval = self.timeoutInterval
            
            //HTTP DATA METHODS
            if(self.method == "POST" || self.method == "PUT"){
                //ADD HTTP BODY
                if(self.images.count > 0 && self.form.count > 0){
                    //MULTIPART FORM DATA
                    self.setMultipartFormData(url, binaryData: self.images, formData: self.form);
                }else if(self.form.count > 0){
                    //FORM DATA
                    self.setFormData(url, formData: self.form);
                }
            }
            
            //ADD BASIC AUTH
            if (self.user != nil && self.password != nil) {
                
                self.log("adding auth \(self.user):\(self.password)")
                
                var encodedAuth: NSData = "\(self.user):\(self.password)".dataUsingEncoding(NSUTF8StringEncoding)!;
                let encodedAuthBase64 = encodedAuth.base64EncodedStringWithOptions(NSDataBase64EncodingOptions.fromRaw(0)!)
                
                url.setValue("Basic \(encodedAuthBase64)", forHTTPHeaderField: "Authorization")
                
            }
            
            //HEADERS
            if(self.headers.count > 0){
                for(name, value) in self.headers {
                    url.setValue(value, forHTTPHeaderField: name);
                }
            }
            
            //SEND SYNC REQUEST
            let result:NSData? = NSURLConnection.sendSynchronousRequest(url, returningResponse: &response, error: &error)
            
            self.log("request result = \(result)")
            self.log("response = \(response)")
            self.log("error = \(error)")
            
            NSOperationQueue.mainQueue().addOperationWithBlock({() -> Void in
                
                self.log("parsing response")
                
                //PROCESS RESPONSE
                let httpResponse:NSHTTPURLResponse? = response as? NSHTTPURLResponse
                
                if (response != nil && httpResponse!.statusCode >= 200 && httpResponse!.statusCode <= 300) {
                    
                    let contentType = httpResponse!.allHeaderFields["Content-Type"] as NSString
                    
                    if(contentType.rangeOfString("application/json").location == NSNotFound) {
                        
                        self.dispatchResponse(false, response: [ "ErrorMessage": "Unexpected contentType: \(contentType)." ])
                        
                    } else {
                        
                        let json : NSDictionary? = NSJSONSerialization.JSONObjectWithData(result!, options: nil, error: &error) as? NSDictionary
                        
                        self.log("json response = \(json)")
                        
                        if (error != nil || json == nil) {
                            self.dispatchResponse(false, response: [ "ErrorMessage": "Error parsing json response." ])
                        } else {
                            self.dispatchResponse(true, response: json!)
                        }
                    }
                } else if (response != nil) {
                    
                    let json : NSDictionary? = NSJSONSerialization.JSONObjectWithData(result!, options: nil, error: &error) as? NSDictionary
                    self.log("json response = \(json)")
                    self.dispatchResponse(false, response: [ "ErrorMessage": "HTTP Status Code \(httpResponse?.statusCode) with repsonse \(response)." ])
                    
                } else {
                    
                    self.dispatchResponse(false, response: [ "ErrorMessage": "HTTP Status Code \(httpResponse?.statusCode)." ])
                    
                }
            })
        });
        
        blockOperation.queuePriority = self.priority
        self.operationQueue.addOperation(blockOperation)
        return self
    }
    
    //HELPER METHODS
    
    private func setMultipartFormData(url: NSMutableURLRequest, binaryData: Dictionary<String, NSData>, formData: Dictionary<String, String>) {
        
        self.log("adding multipart form data")
        
        let uniqueId = NSProcessInfo.processInfo().globallyUniqueString
        let boundary:String = "------WebKitFormBoundary\(uniqueId)"
        
        var postBody:NSMutableData = NSMutableData()
        var postData: String = String();
        
        
        if(formData.count > 0){
            postData = String();
            postData += "--\(boundary)\r\n"
            for(name, value) in formData {
                postData += "--\(boundary)\r\n"
                postData += "Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n"
                postData += "\(value)\r\n"
            }
            postBody.appendData(postData.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!);
        }
        
        
        if(binaryData.count > 0){
            postData = String();
            postData = "--\(boundary)\r\n"
            for(fieldName, file) in binaryData {
                postData += "Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(Int(NSDate().timeIntervalSince1970*1000)).png\"\r\n"
                postData += "Content-Type: image/png\r\n\r\n"
                postBody.appendData(postData.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!);
                postBody.appendData(file)
            }
        }
        
        postData = String();
        postData += "\r\n"
        postData += "\r\n--\(boundary)--\r\n"
        postBody.appendData(postData.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!);
        
        url.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField:"Content-Type")
        
    }
    
    private func setFormData(url: NSMutableURLRequest, formData: Dictionary<String, String>) {
        
        self.log("adding form data")
        
        var formEncoded: String = self.buildParams(formData);
        url.HTTPBody = NSData(data: formEncoded.dataUsingEncoding(NSUTF8StringEncoding)!)
        
        url.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
    }
    
    private func buildParams(params: Dictionary<String, String>) -> String {
        
        self.log("building params")
        
        var parts = [String]();
        
        for(name, value) in params {
            
            self.log("encoded(name, value) -> (\(name),\(value))");
            
            var encodedName: String = name.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())!;
            encodedName = encodedName.stringByReplacingOccurrencesOfString(" ", withString: "+");
            
            var encodedValue: String = value.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())!;
            encodedValue = encodedValue.stringByReplacingOccurrencesOfString(" ", withString: "+");
            
            self.log("encoded(name, value) -> (\(encodedName),\(encodedValue))");
            
            parts.append("\(encodedName)=\(encodedValue)");
            
        }
        
        return join("&", parts);
    }
    
    
    private func dispatchResponse(status: Bool, response: NSDictionary) -> Void {
        
        self.log("dispatching response")
        
        self.response = response
        self.isFailure = status == false
        self.isSuccess = status == true
        self.isComplete = true
        self.responseHandler!(status, response)
    }
    
}
