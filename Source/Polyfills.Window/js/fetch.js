/**
 * http://github.github.io/fetch/
 * Copyright (c) 2014-2016 GitHub, Inc.
 *
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files (the
 * "Software"), to deal in the Software without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject to
 * the following conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
 * LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
 * OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
 * WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 *
 * @preserve-header
 */
self = this;
(function (self) {
	"use strict";

	if (self.fetch) {
		return;
	}

	var support = {
		searchParams: "URLSearchParams" in self,
		iterable: "Symbol" in self && "iterator" in Symbol,
		blob:
			"FileReader" in self &&
			"Blob" in self &&
			(function () {
				try {
					new Blob();
					return true;
				} catch (e) {
					return false;
				}
			})(),
		formData: "FormData" in self,
		arrayBuffer: "ArrayBuffer" in self,
		stream: "ReadableStream" in self,
		writableStream: "WritableStream" in self,
		transformStream: "TransformStream" in self,
		textEncoder: "TextEncoder" in self,
		textDecoder: "TextDecoder" in self,
	};

	function normalizeName(name) {
		if (typeof name !== "string") {
			name = String(name);
		}
		if (/[^a-z0-9\-#$%&'*+.\^_`|~]/i.test(name)) {
			throw new TypeError("Invalid character in header field name");
		}
		return name.toLowerCase();
	}

	function normalizeValue(value) {
		if (typeof value !== "string") {
			value = String(value);
		}
		return value;
	}

	// Build a destructive iterator for the value list
	function iteratorFor(items) {
		var iterator = {
			next: function () {
				var value = items.shift();
				return { done: value === undefined, value: value };
			},
		};

		if (support.iterable) {
			iterator[Symbol.iterator] = function () {
				return iterator;
			};
		}

		return iterator;
	}

	// Ensure TextEncoder/TextDecoder are available
	function ensureTextEncoder() {
		if (!self.TextEncoder) {
			// Simple fallback TextEncoder if polyfill wasn't loaded
			self.TextEncoder = function () {
				this.encoding = "utf-8";
			};
			self.TextEncoder.prototype.encode = function (str) {
				var utf8 = [];
				for (var i = 0; i < str.length; i++) {
					var charcode = str.charCodeAt(i);
					if (charcode < 0x80) {
						utf8.push(charcode);
					} else if (charcode < 0x800) {
						utf8.push(0xc0 | (charcode >> 6), 0x80 | (charcode & 0x3f));
					} else if (charcode < 0xd800 || charcode >= 0xe000) {
						utf8.push(
							0xe0 | (charcode >> 12),
							0x80 | ((charcode >> 6) & 0x3f),
							0x80 | (charcode & 0x3f),
						);
					} else {
						// Surrogate pair
						i++;
						charcode =
							0x10000 +
							(((charcode & 0x3ff) << 10) | (str.charCodeAt(i) & 0x3ff));
						utf8.push(
							0xf0 | (charcode >> 18),
							0x80 | ((charcode >> 12) & 0x3f),
							0x80 | ((charcode >> 6) & 0x3f),
							0x80 | (charcode & 0x3f),
						);
					}
				}
				return new Uint8Array(utf8);
			};
		}

		if (!self.TextDecoder) {
			// Simple fallback TextDecoder if polyfill wasn't loaded
			self.TextDecoder = function (encoding) {
				this.encoding = (encoding || "utf-8").toLowerCase();
			};
			self.TextDecoder.prototype.decode = function (bytes, options) {
				if (!bytes || bytes.length === 0) return "";

				var result = "";
				var i = 0;

				while (i < bytes.length) {
					var byte = bytes[i++];

					if (byte < 0x80) {
						result += String.fromCharCode(byte);
					} else if ((byte & 0xe0) === 0xc0) {
						if (i < bytes.length) {
							var byte2 = bytes[i++];
							result += String.fromCharCode(
								((byte & 0x1f) << 6) | (byte2 & 0x3f),
							);
						}
					} else if ((byte & 0xf0) === 0xe0) {
						if (i + 1 < bytes.length) {
							var byte2 = bytes[i++];
							var byte3 = bytes[i++];
							result += String.fromCharCode(
								((byte & 0x0f) << 12) | ((byte2 & 0x3f) << 6) | (byte3 & 0x3f),
							);
						}
					} else if ((byte & 0xf8) === 0xf0) {
						if (i + 2 < bytes.length) {
							var byte2 = bytes[i++];
							var byte3 = bytes[i++];
							var byte4 = bytes[i++];
							var codePoint =
								((byte & 0x07) << 18) |
								((byte2 & 0x3f) << 12) |
								((byte3 & 0x3f) << 6) |
								(byte4 & 0x3f);
							if (codePoint > 0xffff) {
								codePoint -= 0x10000;
								result += String.fromCharCode(
									0xd800 + (codePoint >> 10),
									0xdc00 + (codePoint & 0x3ff),
								);
							} else {
								result += String.fromCharCode(codePoint);
							}
						}
					}
				}

				return result;
			};
		}
	}

	// Ensure Web Streams are available
	function ensureWebStreams() {
		if (!self.ReadableStream) {
			// Simple fallback ReadableStream if polyfill wasn't loaded
			self.ReadableStream = function ReadableStream(underlyingSource) {
				this._underlyingSource = underlyingSource || {};
				this._state = "readable";
				this._reader = null;
				this._chunks = [];
				this._controller = {
					desiredSize: 1,
					close: () => {
						this._state = "closed";
						if (this._reader && this._reader._readRequests.length > 0) {
							this._reader._readRequests.forEach((request) => {
								request.resolve({ value: undefined, done: true });
							});
							this._reader._readRequests = [];
						}
					},
					enqueue: (chunk) => {
						if (this._state !== "readable") return;
						if (this._reader && this._reader._readRequests.length > 0) {
							var request = this._reader._readRequests.shift();
							request.resolve({ value: chunk, done: false });
						} else {
							this._chunks.push(chunk);
						}
					},
					error: (error) => {
						this._state = "errored";
						this._storedError = error;
						if (this._reader && this._reader._readRequests.length > 0) {
							this._reader._readRequests.forEach((request) => {
								request.reject(error);
							});
							this._reader._readRequests = [];
						}
					},
				};

				if (this._underlyingSource.start) {
					this._underlyingSource.start(this._controller);
				}
			};

			self.ReadableStream.prototype.getReader = function () {
				if (this._reader) {
					throw new TypeError("ReadableStream is locked");
				}
				this._reader = new ReadableStreamDefaultReader(this);
				return this._reader;
			};

			self.ReadableStream.prototype.cancel = function (reason) {
				if (this._underlyingSource.cancel) {
					return this._underlyingSource.cancel(reason);
				}
				return Promise.resolve();
			};

			self.ReadableStream.prototype.pipeTo = function (destination, options) {
				if (!destination || !destination.getWriter) {
					return Promise.reject(
						new TypeError("destination must be a WritableStream"),
					);
				}

				options = options || {};
				const preventClose = options.preventClose;
				const preventAbort = options.preventAbort;
				const preventCancel = options.preventCancel;

				const reader = this.getReader();
				const writer = destination.getWriter();

				function pipeLoop() {
					return reader.read().then((result) => {
						if (result.done) {
							if (!preventClose) {
								return writer.close();
							}
							return Promise.resolve();
						}
						return writer.write(result.value).then(pipeLoop);
					});
				}

				return pipeLoop().finally(() => {
					reader.releaseLock();
					writer.releaseLock();
				});
			};

			self.ReadableStream.prototype.pipeThrough = function (
				transform,
				options,
			) {
				if (!transform || !transform.writable || !transform.readable) {
					throw new TypeError(
						"transform must have writable and readable properties",
					);
				}
				this.pipeTo(transform.writable, options);
				return transform.readable;
			};

			self.ReadableStream.prototype.tee = function () {
				const reader = this.getReader();
				let canceled1 = false;
				let canceled2 = false;
				let reason1, reason2;

				const branch1 = new ReadableStream({
					start(controller) {
						function pullFromSource() {
							return reader.read().then((result) => {
								if (result.done) {
									if (!canceled1) controller.close();
									return;
								}
								if (!canceled1) controller.enqueue(result.value);
								if (!canceled2) branch2._controller.enqueue(result.value);
							});
						}
						this._pullFromSource = pullFromSource;
					},
					pull() {
						return this._pullFromSource();
					},
					cancel(reason) {
						canceled1 = true;
						reason1 = reason;
						if (canceled2) {
							return reader.cancel(
								reason1 === reason2
									? reason1
									: new Error("Both branches canceled"),
							);
						}
						return Promise.resolve();
					},
				});

				const branch2 = new ReadableStream({
					start(controller) {
						branch2._controller = controller;
					},
					pull() {
						return Promise.resolve();
					},
					cancel(reason) {
						canceled2 = true;
						reason2 = reason;
						if (canceled1) {
							return reader.cancel(
								reason1 === reason2
									? reason1
									: new Error("Both branches canceled"),
							);
						}
						return Promise.resolve();
					},
				});

				return [branch1, branch2];
			};

			function ReadableStreamDefaultReader(stream) {
				this._ownerReadableStream = stream;
				this._readRequests = [];
			}

			ReadableStreamDefaultReader.prototype.read = function () {
				var stream = this._ownerReadableStream;
				if (stream._state === "errored") {
					return Promise.reject(stream._storedError);
				}
				if (stream._state === "closed") {
					return Promise.resolve({ value: undefined, done: true });
				}

				if (stream._chunks && stream._chunks.length > 0) {
					var chunk = stream._chunks.shift();
					return Promise.resolve({ value: chunk, done: false });
				}

				return new Promise((resolve, reject) => {
					this._readRequests.push({ resolve, reject });
				});
			};

			ReadableStreamDefaultReader.prototype.cancel = function (reason) {
				return this._ownerReadableStream.cancel(reason);
			};

			ReadableStreamDefaultReader.prototype.releaseLock = function () {
				this._ownerReadableStream._reader = null;
			};

			Object.defineProperty(ReadableStreamDefaultReader.prototype, "closed", {
				get: function () {
					const stream = this._ownerReadableStream;
					if (stream._state === "closed") {
						return Promise.resolve(undefined);
					}
					if (stream._state === "errored") {
						return Promise.reject(stream._storedError);
					}
					return new Promise((resolve, reject) => {
						if (!this._closedPromise) {
							this._closedPromise = { resolve, reject };
						}
					});
				},
			});
		}

		if (!self.WritableStream) {
			// Simple fallback WritableStream if polyfill wasn't loaded
			self.WritableStream = function WritableStream(underlyingSink, strategy) {
				this._underlyingSink = underlyingSink || {};
				this._strategy = strategy || { highWaterMark: 1 };
				this._state = "writable";
				this._writer = null;
				this._writeRequests = [];
				this._backpressure = false;

				if (this._underlyingSink.start) {
					Promise.resolve(this._underlyingSink.start()).catch((error) => {
						this._state = "errored";
						this._storedError = error;
					});
				}
			};

			self.WritableStream.prototype.getWriter = function () {
				if (this._writer) {
					throw new TypeError("WritableStream is locked");
				}
				this._writer = new WritableStreamDefaultWriter(this);
				return this._writer;
			};

			self.WritableStream.prototype.abort = function (reason) {
				if (this._underlyingSink.abort) {
					return this._underlyingSink.abort(reason);
				}
				return Promise.resolve();
			};

			Object.defineProperty(self.WritableStream.prototype, "locked", {
				get: function () {
					return this._writer !== null;
				},
			});

			function WritableStreamDefaultWriter(stream) {
				this._ownerWritableStream = stream;
				this._readyPromise = Promise.resolve();
				this._closedPromise = new Promise((resolve, reject) => {
					this._closedPromise_resolve = resolve;
					this._closedPromise_reject = reject;
				});
			}

			WritableStreamDefaultWriter.prototype.write = function (chunk) {
				const stream = this._ownerWritableStream;
				if (stream._state !== "writable") {
					return Promise.reject(new TypeError("Stream is not writable"));
				}

				return new Promise((resolve, reject) => {
					if (stream._underlyingSink.write) {
						Promise.resolve(stream._underlyingSink.write(chunk))
							.then(resolve)
							.catch(reject);
					} else {
						resolve();
					}
				});
			};

			WritableStreamDefaultWriter.prototype.close = function () {
				const stream = this._ownerWritableStream;
				if (stream._underlyingSink.close) {
					return Promise.resolve(stream._underlyingSink.close()).then(() => {
						stream._state = "closed";
						this._closedPromise_resolve();
					});
				}
				stream._state = "closed";
				this._closedPromise_resolve();
				return Promise.resolve();
			};

			WritableStreamDefaultWriter.prototype.abort = function (reason) {
				return this._ownerWritableStream.abort(reason);
			};

			WritableStreamDefaultWriter.prototype.releaseLock = function () {
				this._ownerWritableStream._writer = null;
			};

			Object.defineProperty(WritableStreamDefaultWriter.prototype, "ready", {
				get: function () {
					return this._readyPromise;
				},
			});

			Object.defineProperty(WritableStreamDefaultWriter.prototype, "closed", {
				get: function () {
					return this._closedPromise;
				},
			});

			Object.defineProperty(
				WritableStreamDefaultWriter.prototype,
				"desiredSize",
				{
					get: function () {
						const stream = this._ownerWritableStream;
						if (stream._state === "errored") return null;
						if (stream._state === "closed") return 0;
						return stream._strategy.highWaterMark || 1;
					},
				},
			);
		}

		if (!self.TransformStream) {
			// Simple fallback TransformStream if polyfill wasn't loaded
			self.TransformStream = function TransformStream(
				transformer,
				writableStrategy,
				readableStrategy,
			) {
				transformer = transformer || {};

				let transformStreamController;

				this._readable = new ReadableStream(
					{
						start(controller) {
							transformStreamController = {
								enqueue(chunk) {
									controller.enqueue(chunk);
								},
								error(error) {
									controller.error(error);
								},
								terminate() {
									controller.close();
								},
								get desiredSize() {
									return controller.desiredSize;
								},
							};

							if (transformer.start) {
								return transformer.start(transformStreamController);
							}
						},
					},
					readableStrategy,
				);

				this._writable = new WritableStream(
					{
						write(chunk) {
							if (transformer.transform) {
								return transformer.transform(chunk, transformStreamController);
							}
							transformStreamController.enqueue(chunk);
						},
						close() {
							if (transformer.flush) {
								return Promise.resolve(
									transformer.flush(transformStreamController),
								).then(() => transformStreamController.terminate());
							}
							transformStreamController.terminate();
						},
					},
					writableStrategy,
				);
			};

			Object.defineProperty(self.TransformStream.prototype, "readable", {
				get: function () {
					return this._readable;
				},
			});

			Object.defineProperty(self.TransformStream.prototype, "writable", {
				get: function () {
					return this._writable;
				},
			});
		}
	}

	// Initialize polyfill support
	ensureTextEncoder();
	ensureWebStreams();

	function Headers(headers) {
		this.map = {};

		if (headers instanceof Headers) {
			headers.forEach(function (value, name) {
				this.append(name, value);
			}, this);
		} else if (headers) {
			Object.getOwnPropertyNames(headers).forEach(function (name) {
				this.append(name, headers[name]);
			}, this);
		}
	}

	Headers.prototype.append = function (name, value) {
		name = normalizeName(name);
		value = normalizeValue(value);
		var list = this.map[name];
		if (!list) {
			list = [];
			this.map[name] = list;
		}
		list.push(value);
	};

	Headers.prototype["delete"] = function (name) {
		delete this.map[normalizeName(name)];
	};

	Headers.prototype.get = function (name) {
		var values = this.map[normalizeName(name)];
		return values ? values[0] : null;
	};

	Headers.prototype.getAll = function (name) {
		return this.map[normalizeName(name)] || [];
	};

	Headers.prototype.has = function (name) {
		return this.map.hasOwnProperty(normalizeName(name));
	};

	Headers.prototype.set = function (name, value) {
		this.map[normalizeName(name)] = [normalizeValue(value)];
	};

	Headers.prototype.forEach = function (callback, thisArg) {
		Object.getOwnPropertyNames(this.map).forEach(function (name) {
			this.map[name].forEach(function (value) {
				callback.call(thisArg, value, name, this);
			}, this);
		}, this);
	};

	Headers.prototype.keys = function () {
		var items = [];
		this.forEach(function (value, name) {
			items.push(name);
		});
		return iteratorFor(items);
	};

	Headers.prototype.values = function () {
		var items = [];
		this.forEach(function (value) {
			items.push(value);
		});
		return iteratorFor(items);
	};

	Headers.prototype.entries = function () {
		var items = [];
		this.forEach(function (value, name) {
			items.push([name, value]);
		});
		return iteratorFor(items);
	};

	if (support.iterable) {
		Headers.prototype[Symbol.iterator] = Headers.prototype.entries;
	}

	function consumed(body) {
		if (body.bodyUsed) {
			return Promise.reject(new TypeError("Already read"));
		}
		body.bodyUsed = true;

		// If there's a body stream, lock it to prevent further reading
		if (body.body && body.body instanceof ReadableStream && !body.body.locked) {
			try {
				body.body.getReader();
			} catch (e) {
				// Stream might already be locked, ignore
			}
		}
	}

	function readArrayBufferAsText(buf) {
		var view = new Uint8Array(buf);
		var chars = new Array(view.length);

		for (var i = 0; i < view.length; i++) {
			chars[i] = String.fromCharCode(view[i]);
		}
		return chars.join("");
	}

	function bufferClone(buf) {
		if (buf.slice) {
			return buf.slice(0);
		} else {
			var view = new Uint8Array(buf.byteLength);
			view.set(new Uint8Array(buf));
			return view.buffer;
		}
	}

	const blobTypes = [
		"audio/",
		"image/",
		"video/",
		"application/pdf",
		"application/zip",
		"application/octet-stream",
		"application/vnd",
	];

	// Utility function to check if header should be allowed on GET/HEAD requests
	function isBodyRelatedHeader(headerName) {
		const lowerName = headerName.toLowerCase();
		return (
			lowerName === "content-type" ||
			lowerName === "content-length" ||
			lowerName === "content-encoding" ||
			lowerName === "content-disposition" ||
			lowerName === "transfer-encoding"
		);
	}

	// Utility function to clean headers for GET/HEAD requests
	function cleanHeadersForGetHead(headers, method) {
		const bodyHeaders = [
			"content-type",
			"content-length",
			"content-encoding",
			"content-disposition",
			"transfer-encoding",
		];

		bodyHeaders.forEach(function (headerName) {
			if (headers.has(headerName)) {
				if (typeof console !== "undefined" && console.warn) {
					console.warn(
						"fetch(): " +
							headerName.toUpperCase() +
							" header is not allowed on " +
							method +
							" requests and will be ignored.",
					);
				}
				headers.delete(headerName);
			}
		});
	}

	function Body() {
		this.bodyUsed = false;

		this._initBody = function (body) {
			this._bodyInit = body;
			const contentType = this.headers.get("content-type");
			if (
				typeof body === "string" &&
				blobTypes.some((type) => contentType.startsWith(type))
			) {
				this._bodyBlob = new Blob([body], { type: contentType });
			} else {
				if (typeof body === "string") {
					this._bodyText = body;
				} else if (support.blob && Blob.prototype.isPrototypeOf(body)) {
					this._bodyBlob = body;
				} else if (support.formData && FormData.prototype.isPrototypeOf(body)) {
					this._bodyFormData = body;
					// Set multipart content-type if not already set
					if (!this.headers.get("content-type")) {
						const boundary = body._getBoundary();
						this.headers.set(
							"content-type",
							"multipart/form-data; boundary=" + boundary,
						);
					}
				} else if (
					support.searchParams &&
					URLSearchParams.prototype.isPrototypeOf(body)
				) {
					this._bodyText = body.toString();
				} else if (!body) {
					this._bodyText = null;
				} else if (
					support.arrayBuffer &&
					ArrayBuffer.prototype.isPrototypeOf(body)
				) {
					this._bodyArrayBuffer = bufferClone(body);
				} else {
					throw new Error("unsupported BodyInit type");
				}
			}

			if (!this.headers.get("content-type")) {
				if (typeof body === "string") {
					this.headers.set("content-type", "text/plain;charset=UTF-8");
				} else if (this._bodyBlob && this._bodyBlob.type) {
					this.headers.set("content-type", this._bodyBlob.type);
				} else if (
					support.searchParams &&
					URLSearchParams.prototype.isPrototypeOf(body)
				) {
					this.headers.set(
						"content-type",
						"application/x-www-form-urlencoded;charset=UTF-8",
					);
				}
			}
		};

		if (support.blob) {
			this.blob = function () {
				var rejected = consumed(this);
				if (rejected) {
					return rejected;
				}

				if (this._bodyBlob) {
					return Promise.resolve(this._bodyBlob);
				} else if (this._bodyFormData) {
					// Convert FormData to multipart blob
					const boundary = this._bodyFormData._getBoundary();
					const multipartData = this._bodyFormData._asMultipart(boundary);
					return Promise.resolve(
						new Blob([multipartData], {
							type: "multipart/form-data; boundary=" + boundary,
						}),
					);
				} else {
					return Promise.resolve(
						new Blob([this._bodyArrayBuffer], {
							type: this.headers.get("content-type"),
						}),
					);
				}
			};
		}
		this.arrayBuffer = async function () {
			var isConsumed = consumed(this);
			if (isConsumed) {
				return isConsumed;
			}

			// Handle ReadableStream body for streaming responses
			if (this.body && this.body instanceof ReadableStream) {
				const reader = this.body.getReader();
				const chunks = [];
				let totalLength = 0;

				try {
					while (true) {
						const { done, value } = await reader.read();
						if (done) break;
						chunks.push(value);
						totalLength += value.byteLength;
					}

					// Combine all chunks into a single ArrayBuffer
					const result = new ArrayBuffer(totalLength);
					const view = new Uint8Array(result);
					let offset = 0;
					for (const chunk of chunks) {
						view.set(chunk, offset);
						offset += chunk.byteLength;
					}
					return result;
				} finally {
					reader.releaseLock();
				}
			}

			if (this._bodyArrayBuffer) {
				if (ArrayBuffer.isView(this._bodyArrayBuffer)) {
					return Promise.resolve(
						this._bodyArrayBuffer.buffer.slice(
							this._bodyArrayBuffer.byteOffset,
							this._bodyArrayBuffer.byteOffset +
								this._bodyArrayBuffer.byteLength,
						),
					);
				} else {
					return Promise.resolve(this._bodyArrayBuffer);
				}
			} else if (support.blob) {
				let blob = await this.blob();
				return blob.arrayBuffer();
			} else {
				throw new Error("could not read as ArrayBuffer");
			}
		};

		this.text = async function () {
			var rejected = consumed(this);
			if (rejected) {
				return rejected;
			}

			// Handle ReadableStream body for streaming responses
			if (this.body && this.body instanceof ReadableStream) {
				const reader = this.body.getReader();
				const decoder = new TextDecoder();
				let result = "";

				try {
					while (true) {
						const { done, value } = await reader.read();
						if (done) break;
						result += decoder.decode(value, { stream: true });
					}
					// Final decode to handle any remaining bytes
					result += decoder.decode();
					return result;
				} finally {
					reader.releaseLock();
				}
			}

			if (this._bodyBlob) {
				let blob = await this.blob();
				return blob.text();
			} else if (this._bodyArrayBuffer) {
				return Promise.resolve(readArrayBufferAsText(this._bodyArrayBuffer));
			} else if (this._bodyFormData) {
				// Convert FormData to URL-encoded string for text representation
				return Promise.resolve(this._bodyFormData.toString());
			} else {
				return Promise.resolve(this._bodyText || "");
			}
		};

		if (support.formData) {
			this.formData = function () {
				return this.text().then(decode);
			};
		}

		this.json = function () {
			return this.text().then(JSON.parse);
		};

		// Add stream() method for body streaming
		if (support.stream) {
			this.body = null; // Will be set by Request/Response constructors if needed

			this.stream = function () {
				var rejected = consumed(this);
				if (rejected) {
					return rejected;
				}

				// Return the actual body stream if available
				if (this.body && this.body instanceof ReadableStream) {
					return this.body;
				}

				// Create streams from different body types
				if (this._bodyBlob && typeof this._bodyBlob.stream === "function") {
					const stream = this._bodyBlob.stream();
					this.body = stream;
					return stream;
				} else if (this._bodyArrayBuffer) {
					const buffer = this._bodyArrayBuffer;
					const stream = new ReadableStream({
						start(controller) {
							const chunk = new Uint8Array(buffer);
							controller.enqueue(chunk);
							controller.close();
						},
					});
					this.body = stream;
					return stream;
				} else if (this._bodyText) {
					const encoder = new TextEncoder();
					const chunk = encoder.encode(this._bodyText);
					const stream = new ReadableStream({
						start(controller) {
							controller.enqueue(chunk);
							controller.close();
						},
					});
					this.body = stream;
					return stream;
				} else if (this._bodyFormData) {
					const boundary = this._bodyFormData._getBoundary();
					const multipartData = this._bodyFormData._asMultipart(boundary);
					const stream = new ReadableStream({
						start(controller) {
							controller.enqueue(multipartData);
							controller.close();
						},
					});
					this.body = stream;
					return stream;
				} else {
					const stream = new ReadableStream({
						start(controller) {
							controller.close();
						},
					});
					this.body = stream;
					return stream;
				}
			};
		}

		return this;
	}

	// HTTP methods whose capitalization should be normalized
	var methods = ["DELETE", "GET", "HEAD", "OPTIONS", "POST", "PUT"];

	function normalizeMethod(method) {
		var upcased = method.toUpperCase();
		return methods.indexOf(upcased) > -1 ? upcased : method;
	}

	function Request(input, options) {
		options = options || {};

		var body = options.body;

		if (input instanceof Request) {
			if (input.bodyUsed) {
				throw new TypeError("Already read");
			}
			this.url = input.url;
			this.credentials = input.credentials;
			if (!options.headers) {
				this.headers = new Headers(input.headers);
			}
			this.method = input.method;
			this.mode = input.mode;
			this.signal = input.signal;
			if (!body && input._bodyInit != null) {
				body = input._bodyInit;
				input.bodyUsed = true;
			}
		} else {
			this.url = String(input);
		}

		this.credentials = options.credentials || this.credentials || "same-origin";
		if (options.headers || !this.headers) {
			this.headers = new Headers(options.headers);
		}
		this.method = normalizeMethod(options.method || this.method || "GET");
		this.mode = options.mode || this.mode || null;
		this.signal = options.signal || this.signal;
		this.referrer = null;

		if ((this.method === "GET" || this.method === "HEAD") && body) {
			throw new TypeError("Body not allowed for GET or HEAD requests");
		}

		// Initialize body property for streaming
		if (support.stream) {
			this.body = null;
		}

		this._initBody(body);

		// Clean body-related headers for GET/HEAD requests
		if (this.method === "GET" || this.method === "HEAD") {
			cleanHeadersForGetHead(this.headers, this.method);
		}
	}

	Request.prototype.clone = function () {
		return new Request(this);
	};

	function decode(body) {
		var form = new FormData();
		body
			.trim()
			.split("&")
			.forEach(function (bytes) {
				if (bytes) {
					var split = bytes.split("=");
					var name = split.shift().replace(/\+/g, " ");
					var value = split.join("=").replace(/\+/g, " ");
					form.append(decodeURIComponent(name), decodeURIComponent(value));
				}
			});
		return form;
	}

	function headers(xhr) {
		var head = new Headers();
		var pairs = (xhr.getAllResponseHeaders() || "").trim().split("\n");
		pairs.forEach(function (header) {
			var split = header.trim().split(":");
			var key = split.shift().trim();
			var value = split.join(":").trim();
			head.append(key, value);
		});
		return head;
	}

	Body.call(Request.prototype);

	function Response(bodyInit, options) {
		if (!options) {
			options = {};
		}

		this.type = "default";
		this.status = options.status === undefined ? 200 : options.status;
		this.ok = this.status >= 200 && this.status < 300;
		this.statusText =
			options.statusText === undefined ? "" : options.statusText;
		this.headers =
			options.headers instanceof Headers
				? options.headers
				: new Headers(options.headers);
		this.url = options.url || "";

		// Initialize body stream property - prioritize options.body for streaming
		if (support.stream) {
			this.body = options.body || null;
		}

		// If options.body is provided (streaming case), don't override with _initBody
		if (options.body && support.stream) {
			this.bodyUsed = false;
			this._bodyInit = bodyInit;
		} else {
			this._initBody(bodyInit);
		}
	}

	Body.call(Response.prototype);

	Response.prototype.clone = function () {
		if (this.bodyUsed) {
			throw new TypeError("Cannot clone response: body already read");
		}

		var clonedBody = null;
		var clonedInit = this._bodyInit;

		// Handle stream cloning
		if (support.stream && this.body instanceof ReadableStream) {
			// Tee the stream so both original and clone can be read
			var teedStreams = this.body.tee();
			this.body = teedStreams[0];
			clonedBody = teedStreams[1];

			// Update the bodyInit to null since we're using streams
			clonedInit = null;
		}

		var cloned = new Response(clonedInit, {
			status: this.status,
			statusText: this.statusText,
			headers: new Headers(this.headers),
			url: this.url,
			body: clonedBody,
		});

		// Copy the body stream to cloned response if we teed it
		if (clonedBody) {
			cloned.body = clonedBody;
		}

		return cloned;
	};

	Response.error = function () {
		var response = new Response(null, { status: 0, statusText: "" });
		response.type = "error";
		return response;
	};

	var redirectStatuses = [301, 302, 303, 307, 308];

	Response.redirect = function (url, status) {
		if (redirectStatuses.indexOf(status) === -1) {
			throw new RangeError("Invalid status code");
		}

		return new Response(null, { status: status, headers: { location: url } });
	};

	self.Headers = Headers;
	self.Request = Request;
	self.Response = Response;

	self.fetch = function (input, init) {
		return new Promise(function (resolve, reject) {
			var request;
			if (Request.prototype.isPrototypeOf(input) && !init) {
				request = input;
			} else {
				request = new Request(input, init);
			}

			var xhr = new XMLHttpRequest();
			xhr.timeout = 60000;
			var stream = null;
			var streamController = null;
			var aborted = false;

			// Abort handler function
			function abortXhr() {
				aborted = true;
				xhr.abort();
				if (streamController) {
					streamController.error(new Error("Request aborted"));
				}
				reject(new Error("Request aborted"));
			}

			// Set up abort signal if provided
			if (request.signal) {
				if (request.signal.aborted) {
					abortXhr();
					return;
				}
				request.signal.addEventListener("abort", abortXhr);
			}

			function responseURL() {
				if ("responseURL" in xhr) {
					return xhr.responseURL;
				}

				// Avoid security warnings on getResponseHeader when not allowed by CORS
				if (/^X-Request-URL:/m.test(xhr.getAllResponseHeaders())) {
					return xhr.getResponseHeader("X-Request-URL");
				}

				return;
			}

			// Create ReadableStream for streaming responses (opt-in only)
			if (init && init.stream === true) {
				console.log("🚀 Streaming enabled for request to:", request.url);
				stream = new ReadableStream({
					start: function (controller) {
						streamController = controller;
						console.log("📡 Stream controller initialized");
					},
					cancel: function () {
						console.log("🛑 Stream cancelled by consumer");
						xhr.abort();
					},
				});
			}

			var lastResponseLength = 0;
			var streamingInterval = null;
			var pendingData = "";

			// Enhanced streaming processor for SSE responses
			function processStreamingData(newData, isFinal) {
				if (!streamController) return;

				pendingData += newData;

				// If this looks like SSE, process line by line
				if (pendingData.includes("data:") || pendingData.includes("\n")) {
					var lines = pendingData.split("\n");

					// Keep the last incomplete line for next batch (unless final)
					if (!isFinal && lines.length > 0) {
						var lastLine = lines[lines.length - 1];
						if (!lastLine.trim() || !lastLine.includes("data:")) {
							pendingData = lines.pop();
						} else {
							pendingData = "";
						}
					} else {
						pendingData = "";
					}

					// Process complete lines
					for (var i = 0; i < lines.length; i++) {
						var line = lines[i];
						if (line.trim()) {
							console.log("📊 Processing SSE line:", line.substring(0, 100));
							var encoder = new TextEncoder();
							streamController.enqueue(encoder.encode(line + "\n"));
						}
					}
				} else {
					// Non-SSE streaming data
					console.log("📊 Processing raw chunk:", newData.length, "bytes");
					var encoder = new TextEncoder();
					streamController.enqueue(encoder.encode(newData));
					pendingData = "";
				}
			}

			var streamingResponseResolved = false;

			// Helper function to resolve streaming response
			function resolveStreamingResponse() {
				if (streamingResponseResolved) return;
				streamingResponseResolved = true;

				console.log("📋 Headers available, resolving streaming response");
				var allHeaders = xhr.getAllResponseHeaders();
				console.log("🔍 Response headers:", allHeaders);

				var options = {
					status: xhr.status,
					statusText: xhr.statusText,
					headers: headers(xhr),
					url: responseURL(),
					body: stream,
				};

				console.log(
					"📤 Resolving with streaming response, status:",
					xhr.status,
				);
				resolve(new Response(null, options));

				// Process any data that's already available
				var responseText = xhr.responseText || "";
				if (responseText.length > 0) {
					console.log(
						"📊 Processing existing data:",
						responseText.length,
						"bytes",
					);
					processStreamingData(responseText, xhr.readyState === 4);
					lastResponseLength = responseText.length;
				}

				// Start polling for streaming data
				console.log("⏰ Starting polling interval for streaming data");
				streamingInterval = setInterval(function () {
					if (xhr.readyState >= 3 && streamController && !aborted) {
						var responseText = xhr.responseText || "";
						if (responseText.length > lastResponseLength) {
							var newData = responseText.slice(lastResponseLength);
							lastResponseLength = responseText.length;
							processStreamingData(newData, false);
						}

						if (xhr.readyState === 4) {
							clearInterval(streamingInterval);
							streamingInterval = null;
						}
					}
				}, 5); // Fast polling for streaming
			}

			xhr.onreadystatechange = function () {
				console.log(
					"🔄 ReadyState changed to:",
					xhr.readyState,
					"Status:",
					xhr.status,
				);

				if (xhr.readyState === 2) {
					// HEADERS_RECEIVED - ideal case
					if (stream) {
						resolveStreamingResponse();
					}
				} else if (xhr.readyState === 3) {
					// LOADING - fallback case if ReadyState 2 was skipped
					if (stream && !streamingResponseResolved) {
						console.log(
							"⚠️ ReadyState 2 was skipped, resolving at ReadyState 3",
						);
						resolveStreamingResponse();
					} else if (stream && streamController) {
						// Process data if already resolved
						console.log("⚡ ReadyState 3 - immediate processing");
						var responseText = xhr.responseText || "";
						if (responseText.length > lastResponseLength) {
							var newData = responseText.slice(lastResponseLength);
							lastResponseLength = responseText.length;
							processStreamingData(newData, false);
						}
					}
				} else if (xhr.readyState === 4) {
					// DONE - final fallback if neither 2 nor 3 resolved streaming
					if (stream && !streamingResponseResolved) {
						console.log(
							"⚠️ ReadyStates 2&3 were skipped, resolving at ReadyState 4",
						);
						resolveStreamingResponse();
					}
				}
			};

			xhr.onload = function () {
				if (request.signal) {
					request.signal.removeEventListener("abort", abortXhr);
				}

				if (aborted) return;

				// Clear streaming interval
				if (streamingInterval) {
					clearInterval(streamingInterval);
					streamingInterval = null;
				}

				if (streamController) {
					// Process any final data
					var responseText = xhr.responseText || "";
					console.log(
						"🏁 Final response length:",
						responseText.length,
						"Last processed:",
						lastResponseLength,
					);

					if (responseText.length > lastResponseLength) {
						var newData = responseText.slice(lastResponseLength);
						console.log("📊 Final chunk:", newData.length, "bytes");
						processStreamingData(newData, true);
					}

					// Process any remaining pending data
					if (pendingData.trim()) {
						console.log("📊 Processing final pending data");
						var encoder = new TextEncoder();
						streamController.enqueue(encoder.encode(pendingData));
					}

					console.log("🔚 Closing stream controller");
					streamController.close();

					// Debug analysis
					if (responseText.includes("data:") && responseText.includes("\n")) {
						console.log("💡 Confirmed: Server-Sent Events response!");
						console.log("🔍 Total lines:", responseText.split("\n").length);
					}
				} else {
					var options = {
						status: xhr.status,
						statusText: xhr.statusText,
						headers: headers(xhr),
						url: responseURL(),
					};
					var body = "response" in xhr ? xhr.response : xhr.responseText;

					// For non-streaming responses, create proper body stream
					if (support.stream && body) {
						var responseStream;
						if (typeof body === "string") {
							var encoder = new TextEncoder();
							var chunk = encoder.encode(body);
							responseStream = new ReadableStream({
								start(controller) {
									controller.enqueue(chunk);
									controller.close();
								},
							});
						} else if (body instanceof ArrayBuffer) {
							var chunk = new Uint8Array(body);
							responseStream = new ReadableStream({
								start(controller) {
									controller.enqueue(chunk);
									controller.close();
								},
							});
						}
						options.body = responseStream;
					}

					resolve(new Response(body, options));
				}
			};

			xhr.onerror = function () {
				if (request.signal) {
					request.signal.removeEventListener("abort", abortXhr);
				}

				if (aborted) return;

				// Clear streaming interval
				if (streamingInterval) {
					clearInterval(streamingInterval);
					streamingInterval = null;
				}

				if (streamController) {
					streamController.error(new TypeError("Network request failed"));
				}
				reject(new TypeError("Network request failed"));
			};

			xhr.ontimeout = function () {
				if (request.signal) {
					request.signal.removeEventListener("abort", abortXhr);
				}

				if (aborted) return;

				// Clear streaming interval
				if (streamingInterval) {
					clearInterval(streamingInterval);
					streamingInterval = null;
				}

				if (streamController) {
					streamController.error(new TypeError("Network request timed out"));
				}
				reject(new TypeError("Network request timed out"));
			};

			console.log(
				"🌐 Opening XHR:",
				request.method,
				request.url,
				"streaming:",
				!!stream,
			);
			xhr.open(request.method, request.url, true);

			if (request.credentials === "include") {
				xhr.withCredentials = true;
			}

			if ("responseType" in xhr && !stream) {
				if (support.arrayBuffer) {
					xhr.responseType = "arraybuffer";
				}
			} else if (stream) {
				console.log("📡 Streaming mode - keeping default responseType");
			}

			request.headers.forEach(function (value, name) {
				// Skip body-related headers for GET/HEAD requests (double-check)
				if (
					(request.method === "GET" || request.method === "HEAD") &&
					isBodyRelatedHeader(name)
				) {
					// These should already be cleaned, but double-check
					if (typeof console !== "undefined" && console.warn) {
						console.warn(
							"fetch(): Skipping " +
								name +
								" header on " +
								request.method +
								" request",
						);
					}
					return; // Skip this header
				}
				xhr.setRequestHeader(name, value);
			});

			// Handle FormData serialization for XMLHttpRequest
			let body = request._bodyInit;
			if (body && support.formData && FormData.prototype.isPrototypeOf(body)) {
				// For polyfilled FormData, we need to convert to multipart data
				if (body.polyfill && typeof body._asMultipart === "function") {
					const boundary = body._getBoundary();
					body = body._asMultipart(boundary);
				}
				// For native FormData, XMLHttpRequest will handle it automatically
			}

			// For GET/HEAD requests or empty body, always send null
			if (
				request.method === "GET" ||
				request.method === "HEAD" ||
				!body ||
				body === ""
			) {
				xhr.send(null);
			} else {
				xhr.send(body);
			}
		});
	};
	self.fetch.polyfill = true;

	// AbortController and AbortSignal polyfills
	if (!self.AbortController) {
		self.AbortSignal = function () {
			this.aborted = false;
			this._listeners = [];
		};

		self.AbortSignal.prototype.addEventListener = function (type, listener) {
			if (type === "abort" && typeof listener === "function") {
				this._listeners.push(listener);
			}
		};

		self.AbortSignal.prototype.removeEventListener = function (type, listener) {
			if (type === "abort") {
				var index = this._listeners.indexOf(listener);
				if (index !== -1) {
					this._listeners.splice(index, 1);
				}
			}
		};

		self.AbortSignal.prototype.dispatchEvent = function (event) {
			if (event.type === "abort") {
				this.aborted = true;
				this._listeners.forEach(function (listener) {
					listener.call(this, event);
				});
			}
		};

		self.AbortController = function () {
			this.signal = new AbortSignal();
		};

		self.AbortController.prototype.abort = function () {
			if (!this.signal.aborted) {
				this.signal.dispatchEvent({ type: "abort" });
			}
		};

		self.AbortController.polyfill = true;
		self.AbortSignal.polyfill = true;
	}
})(typeof self !== "undefined" ? self : this);
