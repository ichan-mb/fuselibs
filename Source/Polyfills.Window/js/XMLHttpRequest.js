(function (window, HttpClient) {
	"use strict";

	var HttpRequestState = {
		Uninitialized: 0,
		Opened: 1,
		Sent: 2,
		HeadersReceived: 3,
		Loading: 4,
		Done: 5,
		Aborted: 6,
		Errored: 7,
		TimedOut: 8,
	};

	var ProgressEvent = function ProgressEvent(loaded, total, lengthComputable) {
		Object.defineProperties(this, {
			total: { value: total },
			loaded: { value: loaded },
			lengthComputable: { value: lengthComputable },
		});
	};

	var fuseXMLHttpRequest = function fuseXMLHttpRequest() {
		var a = Object.create(fuseXMLHttpRequest.prototype);
		var propertyDescriptors = new Object();

		propertyDescriptors._fuseHttpClient = {
			value: new HttpClient(),
		};

		propertyDescriptors._fuseHttpRequest = {
			value: null,
			writable: true,
		};

		propertyDescriptors.status = {
			get: function () {
				if (this._fuseHttpRequest === null) return 0;
				return this._fuseHttpRequest.getResponseStatus();
			},
		};

		propertyDescriptors.statusText = {
			get: function () {
				if (this._fuseHttpRequest === null) return "";
				return this._fuseHttpRequest.getResponseReasonPhrase();
			},
		};

		propertyDescriptors.response = {
			get: function () {
				if (this._fuseHttpRequest === null) return "";

				var responseType = this._fuseHttpRequest.getResponseType();

				if (responseType == 1) {
					// ByteArray response type
					try {
						var byteArray = this._fuseHttpRequest.getResponseContentByteArray();
						return byteArray;
					} catch (e) {
						return new byte[0]();
					}
				} else {
					// String or Stream response type - return streaming buffer only if streaming is enabled and has content
					var response = "";
					if (
						this._streamingEnabled &&
						this._streamingBuffer !== undefined &&
						this._streamingBuffer !== ""
					) {
						response = this._streamingBuffer;
					} else {
						try {
							response = this._fuseHttpRequest.getResponseContentString();
						} catch (e) {
							response = "";
						}
					}
					return response;
				}
			},
		};

		propertyDescriptors.responseText = {
			get: function () {
				if (this._fuseHttpRequest === null) return "";
				// For streaming responses, return the streaming buffer
				// For other response types, use the normal response content
				var responseText = "";
				if (
					this._streamingEnabled &&
					this._streamingBuffer !== undefined &&
					this._streamingBuffer !== ""
				) {
					responseText = this._streamingBuffer;
				} else {
					try {
						responseText = this._fuseHttpRequest.getResponseContentString();
					} catch (e) {
						responseText = "";
					}
				}
				return responseText;
			},
		};

		propertyDescriptors.responseType = {
			get: function () {
				if (this._fuseHttpRequest === null) return "text";
				var responseType = this._fuseHttpRequest.getResponseType();
				if (responseType == 1) return "arraybuffer";
				if (responseType == 2) return "stream";
				return "text";
			},
			set: function (value) {
				if (this._fuseHttpRequest === null) return;
				var type = 0; // Default to String
				if (value.toLowerCase() == "arraybuffer") {
					type = 1; // ByteArray
				} else if (value.toLowerCase() == "stream") {
					type = 2; // Stream
				}
				this._fuseHttpRequest.setResponseType(type);
			},
		};

		propertyDescriptors.readyState = {
			get: function () {
				if (this._fuseHttpRequest === null) return 0;

				var state = this._fuseHttpRequest.getState();
				if (state <= HttpRequestState.Uninitialized)
					return fuseXMLHttpRequest.UNSENT;
				if (state == HttpRequestState.Opened) return fuseXMLHttpRequest.OPENED;
				if (state == HttpRequestState.HeadersReceived)
					return fuseXMLHttpRequest.HEADERS_RECEIVED;
				if (state == HttpRequestState.Loading)
					return fuseXMLHttpRequest.LOADING;
				if (state >= HttpRequestState.Done) return fuseXMLHttpRequest.DONE;
				return fuseXMLHttpRequest.UNSENT;
			},
		};

		Object.defineProperties(a, propertyDescriptors);
		return a;
	};

	fuseXMLHttpRequest.UNSENT = 0;
	fuseXMLHttpRequest.OPENED = 1;
	fuseXMLHttpRequest.HEADERS_RECEIVED = 2;
	fuseXMLHttpRequest.LOADING = 3;
	fuseXMLHttpRequest.DONE = 4;

	fuseXMLHttpRequest.onloadstart = null;
	fuseXMLHttpRequest.onprogress = null;
	fuseXMLHttpRequest.onabort = null;
	fuseXMLHttpRequest.onerror = null;
	fuseXMLHttpRequest.onload = null;
	fuseXMLHttpRequest.ontimeout = null;
	fuseXMLHttpRequest.onloadend = null;

	fuseXMLHttpRequest.prototype.onreadystatechange = null;
	fuseXMLHttpRequest.prototype.timeout = 0;
	fuseXMLHttpRequest.prototype.withCredentials = false;
	fuseXMLHttpRequest.prototype.upload = null;

	fuseXMLHttpRequest.prototype.open = function (
		method,
		url,
		async,
		username,
		password,
	) {
		var self = this;
		var progressEvent = new ProgressEvent(0, 0, false);
		var contentLength = 0;

		// Initialize streaming variables only when streaming is detected
		this._streamingBuffer = undefined;
		this._streamingEnabled = false;

		if (self._fuseHttpRequest !== null) self._fuseHttpRequest.abort();
		self._fuseHttpRequest = self._fuseHttpClient.createRequest(method, url);

		if (self._fuseHttpRequest && self._fuseHttpRequest !== false) {
			self._fuseHttpRequest.enableCache(true);
			// Explicitly set response type to String (0) for basic requests
			self._fuseHttpRequest.setResponseType(0);
		}
		// Check for alternative streaming method names
		var streamingMethods = [
			"setStreamingDataCallback",
			"setStreamingCallback",
			"setStreamCallback",
			"setOnStreamingData",
			"setOnStreamData",
			"enableStreaming",
			"setStreamMode",
		];

		var foundStreamingMethod = null;
		for (var i = 0; i < streamingMethods.length; i++) {
			var methodName = streamingMethods[i];
			if (
				self._fuseHttpRequest &&
				typeof self._fuseHttpRequest[methodName] === "function"
			) {
				foundStreamingMethod = methodName;
				break;
			}
		}

		if (foundStreamingMethod) {
			self._streamingEnabled = true;
			self._streamingMethodName = foundStreamingMethod;
			self._streamingBuffer = ""; // Initialize buffer only when streaming is enabled
		} else if (
			self._fuseHttpRequest &&
			self._fuseHttpRequest.setStreamingDataCallback
		) {
			self._streamingEnabled = true;
			self._streamingBuffer = ""; // Initialize buffer only when streaming is enabled
		}

		if (self._fuseHttpRequest.getState() === HttpRequestState.Opened) {
			dispatch.call(self, "readystatechange");
		}

		self._fuseHttpRequest.onstatechanged = function (state) {
			if (state === HttpRequestState.HeadersReceived) {
				dispatch.call(self, "readystatechange");

				var cl = parseInt(self.getResponseHeader("Content-Length"));
				contentLength = cl === NaN ? 0 : cl;
				progressEvent = new ProgressEvent(0, contentLength, contentLength > 0);
				dispatch.call(self, "loadstart", progressEvent);
			} else if (
				state === HttpRequestState.Loading ||
				state === HttpRequestState.Done
			) {
				dispatch.call(self, "readystatechange");
			}
		};
		self._fuseHttpRequest.ondone = function () {
			dispatch.call(self, "load");
			dispatch.call(self, "loadend", progressEvent);
		};
		self._fuseHttpRequest.onabort = function () {
			dispatch.call(self, "abort");
			dispatch.call(self, "loadend", progressEvent);
		};
		self._fuseHttpRequest.onerror = function (error) {
			dispatch.call(self, "error", new Error(error));
			dispatch.call(self, "loadend", progressEvent);
		};
		self._fuseHttpRequest.onprogress = function (current, total, hastotal) {
			progressEvent = new ProgressEvent(current, total, hastotal);
			dispatch.call(self, "progress", progressEvent);
		};
		self._fuseHttpRequest.ontimeout = function () {
			dispatch.call(self, "timeout");
			dispatch.call(self, "loadend", progressEvent);
		};

		// Enable streaming for Server-Sent Events and similar use cases
		// Set up streaming callback with String response type (type 0)
		if (self._streamingEnabled && self._streamingMethodName) {
			var xhrSelf = self; // Capture the correct 'this' context
			var lastProcessedDataHash = null; // Track last processed data to prevent duplicates

			// Create the streaming data handler function
			var streamingHandler = function (data, isComplete) {
				// Check for duplicate data by comparing first/last elements and length
				if (data && data.length > 0) {
					var dataHash =
						data.length + "_" + data[0] + "_" + data[data.length - 1];
					if (dataHash === lastProcessedDataHash) {
						return;
					}
					lastProcessedDataHash = dataHash;
				}

				if (isComplete) {
					// Signal completion to onchunk handler if it exists
					if (typeof self.onchunk === "function") {
						// Call onchunk with empty chunk and isComplete flag immediately
						self.onchunk("", xhrSelf._streamingBuffer, true);
					}

					// Stream completed - final readyState change will be handled by ondone
					return;
				}

				// Convert byte array to string for text responses
				var chunk = "";
				if (data && data.length > 0) {
					// Data comes as JavaScript array from Uno layer
					if (Array.isArray(data)) {
						for (var i = 0; i < data.length; i++) {
							var charCode = data[i];
							if (typeof charCode === "number") {
								chunk += String.fromCharCode(charCode & 0xff);
							}
						}
					} else if (data instanceof ArrayBuffer) {
						var uint8Array = new Uint8Array(data);
						for (var i = 0; i < uint8Array.length; i++) {
							chunk += String.fromCharCode(uint8Array[i]);
						}
					}
				}

				if (!xhrSelf._streamingBuffer) {
					xhrSelf._streamingBuffer = "";
				}

				// Append chunk to buffer and fire onchunk immediately
				if (chunk && chunk.length > 0) {
					var previousLength = xhrSelf._streamingBuffer.length;
					xhrSelf._streamingBuffer += chunk;

					// Fire onchunk IMMEDIATELY with the new chunk
					if (typeof self.onchunk === "function") {
						// Call onchunk immediately - no setTimeout needed
						self.onchunk(chunk, xhrSelf._streamingBuffer, false);
					}

					// Trigger readyState change for first chunk
					if (self.readyState === fuseXMLHttpRequest.HEADERS_RECEIVED) {
						// Don't set readyState directly - it's readonly and managed internally
						// Just dispatch the event to notify listeners
						dispatch.call(self, "readystatechange");
					}

					// Fire progress event
					var current = xhrSelf._streamingBuffer.length;
					progressEvent = new ProgressEvent(
						current,
						contentLength,
						contentLength > 0,
					);
					dispatch.call(self, "progress", progressEvent);
				}
			};

			// Set up the streaming callback using the detected method
			self._fuseHttpRequest[self._streamingMethodName](streamingHandler);

			// Also set the onstreamingdata property for event-based mechanism
			// This is crucial for the Http.uno OnStreamingData handler to find the callback
			self._fuseHttpRequest.onstreamingdata = streamingHandler;
		}
	};

	fuseXMLHttpRequest.prototype.send = function (data) {
		if (this._fuseHttpRequest !== null) {
			this._fuseHttpRequest.setTimeout(this.timeout);
			this._fuseHttpRequest.sendAsync(data);
		} else throw "InvalidStateError";
	};

	fuseXMLHttpRequest.prototype.setRequestHeader = function (header, value) {
		if (this._fuseHttpRequest === null) return;
		return this._fuseHttpRequest.setHeader(header, value + "");
	};

	fuseXMLHttpRequest.prototype.abort = function () {
		if (this._fuseHttpRequest === null) return;
		return this._fuseHttpRequest.abort();
	};

	fuseXMLHttpRequest.prototype.getResponseHeader = function (header) {
		if (this._fuseHttpRequest === null) return;
		return this._fuseHttpRequest.getResponseHeader(header);
	};

	fuseXMLHttpRequest.prototype.overrideMimeType = function (mime) {
		// Ignore
	};

	fuseXMLHttpRequest.prototype.getAllResponseHeaders = function () {
		if (this._fuseHttpRequest === null) return;
		return this._fuseHttpRequest.getResponseHeaders();
	};

	if (window.EventTarget != "undefined") {
		fuseXMLHttpRequest.prototype.addEventListener =
			window.EventTarget.prototype.addEventListener;
		fuseXMLHttpRequest.prototype.removeEventListener =
			window.EventTarget.prototype.removeEventListener;
		fuseXMLHttpRequest.prototype.dispatchEvent =
			window.EventTarget.prototype.dispatchEvent;
	}

	function isAnyObject(value) {
		return (
			value != null &&
			(typeof value === "object" || typeof value === "function")
		);
	}

	function dispatch(eventName, arg) {
		if (typeof this.dispatchEvent === "function") {
			if (typeof arg === "undefined") arg = {};

			if (isAnyObject(arg)) arg.type = eventName;
			else throw new Error("Invalid event object");

			this.dispatchEvent(arg);
		}

		if (typeof this["on" + eventName] === "function") {
			if (typeof arg === "undefined") this["on" + eventName]();
			else this["on" + eventName](arg);
		}
	}

	window.XMLHttpRequest = fuseXMLHttpRequest;
})(window, require("FuseJS/Http"));

XMLHttpRequest = window.XMLHttpRequest;
