# Chat Debug Guide - Why You're Getting Fallback Responses

## 🔍 What to Check

When you send a message and get the same fallback response ("Every tree matters..."), check the **Output panel** in Godot for these messages:

### 1. **API Key Status**
Look for:
```
[API KEY CHECK] Checking for API key...
API Key Status: FOUND
```
If it says "NOT FOUND", the API key isn't configured correctly.

### 2. **Request Status**
Look for:
```
[LORAX CHAT] Making HTTP request...
[LORAX CHAT] HTTP request sent successfully. Waiting for response...
```

### 3. **Response Status**
Look for:
```
[API RESPONSE] HTTP Response code: 200
```
- **200** = Success (should work)
- **400** = Bad request (format issue)
- **401** = Unauthorized (API key invalid)
- **429** = Rate limit exceeded

### 4. **Response Content**
Look for:
```
[API RESPONSE] Extracted text: [actual response]
```
If this is empty, the API returned a response but we couldn't parse it.

## 🐛 Common Issues

### Issue: Always Getting Fallback Responses

**Symptom:** Every message gets "Every tree matters. Every leaf counts."

**Possible Causes:**
1. **API Key Invalid** - Check for HTTP 401 errors
2. **Request Format Wrong** - Check for HTTP 400 errors  
3. **Network Issue** - Check for connection errors
4. **Empty Response** - API returned but response is empty

**Solution:** Check the Output panel for the specific error message and HTTP code.

### Issue: API Returns 400 (Bad Request)

This means the request format is wrong. The current format should work, but if you see 400:
- Check that the JSON is valid
- Verify the `contents` array format
- Make sure `role` is "user" or "model"

### Issue: API Returns 401 (Unauthorized)

This means the API key is invalid or expired.
- Verify the key in `project.godot`
- Check if the key has proper permissions
- Try regenerating the key

## 📋 What the Debug Output Should Show

**Successful API Call:**
```
[LORAX CHAT] User message: hello
[LORAX CHAT] Making API call with 1 messages in history...
[LORAX CHAT] HTTP request sent successfully. Waiting for response...
[API RESPONSE] HTTP Response code: 200
[API RESPONSE] Extracted text: Hello! I speak for the trees...
[CHAT] Lorax message received: Hello! I speak for the trees...
```

**Failed API Call:**
```
[LORAX CHAT] User message: hello
[API RESPONSE] HTTP Response code: 401
[API RESPONSE] Response body: {"error": {"message": "API key not valid"}}
[LORAX CHAT] Using fallback response (API unavailable or failed)
```

## 🎯 Next Steps

1. **Run the game** and send a message
2. **Check the Output panel** for the debug messages above
3. **Look for HTTP error codes** (400, 401, etc.)
4. **Share the error messages** you see and I can help fix them!

The debug output will tell us exactly what's going wrong! 🔍
