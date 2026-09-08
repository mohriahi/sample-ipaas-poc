import ballerina/http;
import ballerina/time;
// UNCOMMENT THE BELOW LINES TO ENABLE INTEGRATION CONTROL PLANE 
// import wso2/icp.runtime.bridge as _;

# Response returned by the greeting service.
#
# + message - formatted greeting message
# + timestamp - UTC date and time the response was generated (ISO 8601 format)
type GreetingResponse record {|
    string message;
    string timestamp;
|};

# "Hello World" integration service.
#
# Demo service exposing a generic or personalized greeting, used as an
# integration example for the iPaaS POC.
service /hello on new http:Listener(9095) {

    # Returns a generic greeting.
    #
    # + return - a generic greeting message
    resource function get .() returns GreetingResponse {
        return {
            message: "Hello, World!",
            timestamp: time:utcToString(time:utcNow())
        };
    }

    # Returns a personalized greeting for the given person.
    #
    # + name - name of the person to greet
    # + return - a personalized greeting message
    resource function get [string name]() returns GreetingResponse {
        return {
            message: string `Hello, ${name}!`,
            timestamp: time:utcToString(time:utcNow())
        };
    }
}
