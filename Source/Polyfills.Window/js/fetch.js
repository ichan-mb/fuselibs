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

			// Native Uno HTTP Streaming Implementation
			// This replaces the previous XMLHttpRequest polling approach with true
			// event-driven streaming using the native Uno HTTP infrastructure.
			// Benefits:
			// - Real-time chunk processing (no 5ms polling delay)
			// - Memory efficient (only current chunk in memory)
			// - Uses platform-native streaming (iOS NSURLSession, Android HttpURLConnection)
			// - Event-driven callbacks instead of continuous polling

			// Check if streaming is requested
			var isStreamingEnabled = init && init.stream === true;
			var stream = null;
			var streamController = null;
			var aborted = false;
			var streamClosed = false;

			// Use XMLHttpRequest which already has streaming support working
			var xhr = new XMLHttpRequest();
			var pendingData = "";
			var streamingCheckInterval = null;
			var lastBufferLength = 0;

			// Create ReadableStream for streaming responses
			if (isStreamingEnabled) {
				try {
					stream = new ReadableStream({
						start: function (controller) {
							streamController = controller;
						},
						cancel: function () {
							aborted = true;
							if (xhr) {
								xhr.abort();
							}
						},
					});
				} catch (streamError) {
					console.error("❌ Error creating ReadableStream:", streamError);
					throw streamError;
				}
			}

			// Ensure WebStreams are available before proceeding
			ensureWebStreams();

			// Abort handler function
			function abortRequest() {
				aborted = true;

				// Clean up streaming monitoring
				if (streamingCheckInterval) {
					clearInterval(streamingCheckInterval);
					streamingCheckInterval = null;
				}

				if (xhr) {
					xhr.abort();
				}
				if (streamController) {
					streamController.error(new Error("Request aborted"));
				}
				reject(new Error("Request aborted"));
			}

			// Set up abort signal if provided
			if (request.signal) {
				if (request.signal.aborted) {
					abortRequest();
					return;
				}
				request.signal.addEventListener("abort", abortRequest);
			}
			// Configure XMLHttpRequest
			xhr.timeout = init && init.timeout ? init.timeout : 60000;

			xhr.open(request.method, request.url, true);

			if (request.credentials === "include") {
				xhr.withCredentials = true;
			}

			// Set headers
			request.headers.forEach(function (value, name) {
				// Skip body-related headers for GET/HEAD requests
				if (
					(request.method === "GET" || request.method === "HEAD") &&
					isBodyRelatedHeader(name)
				) {
					if (typeof console !== "undefined" && console.warn) {
						console.warn(
							"fetch(): Skipping " +
								name +
								" header on " +
								request.method +
								" request",
						);
					}
					return;
				}
				xhr.setRequestHeader(name, value);
			});

			// Set up XMLHttpRequest streaming using existing streaming buffer
			if (isStreamingEnabled) {
				// Set response type to Stream for proper streaming mode
				if (xhr._fuseHttpRequest && xhr._fuseHttpRequest.setResponseType) {
					xhr._fuseHttpRequest.setResponseType(2); // Stream = 2
				}

				var pendingData = "";

				// Set up onstreamingdata handler to connect HttpMessageHandlerRequest streaming to fetch.js
				xhr.onstreamingdata = function (data, isComplete) {
					if (!streamController || aborted || streamClosed) {
						return;
					}

					// Convert byte array to string
					var chunk = "";
					if (data && data.length > 0) {
						for (var i = 0; i < data.length; i++) {
							chunk += String.fromCharCode(data[i]);
						}
					}

					if (isComplete) {
						// Process any remaining chunk data
						if (chunk && chunk.length > 0) {
							var encoder = new TextEncoder();
							streamController.enqueue(encoder.encode(chunk));
						}

						streamController.close();
						streamController = null;
						streamClosed = true;
						return;
					}

					// Check for [DONE] marker which indicates completion
					var isDoneChunk = false;
					if (chunk && chunk.indexOf("[DONE]") !== -1) {
						isDoneChunk = true;
					}

					// Process Server-Sent Events format if detected
					if (chunk && (chunk.includes("data:") || chunk.includes("\n"))) {
						var lines = chunk.split("\n");

						for (var i = 0; i < lines.length; i++) {
							var line = lines[i];
							if (line.trim()) {
								var encoder = new TextEncoder();
								var encodedLine = encoder.encode(line + "\n");
								streamController.enqueue(encodedLine);
							}
						}
					} else if (chunk && chunk.length > 0) {
						// Raw streaming data
						var encoder = new TextEncoder();
						var encodedData = encoder.encode(chunk);
						streamController.enqueue(encodedData);
					}

					// Force completion if we detected [DONE] marker
					if (isDoneChunk && !streamClosed) {
						// Schedule closure to allow current chunk processing to complete
						setTimeout(function () {
							if (!streamClosed && streamController) {
								streamController.close();
								streamController = null;
								streamClosed = true;
							}
						}, 200);
						return;
					}
				};

				// Set up direct streaming callback
				if (xhr._streamingEnabled && xhr._streamingBuffer !== undefined) {
					// Track last processed position
					var lastProcessedLength = 0;

					// Set up onchunk handler for XMLHttpRequest's streaming events
					xhr.onchunk = function (chunk, buffer, isComplete) {
						if (!streamController || aborted || streamClosed) {
							return;
						}

						// Handle stream completion
						if (isComplete) {
							// Process any final data if buffer has grown
							if (buffer && buffer.length > lastProcessedLength) {
								var finalData = buffer.substring(lastProcessedLength);
								if (finalData.length > 0) {
									var encoder = new TextEncoder();
									streamController.enqueue(encoder.encode(finalData));
								}
							}

							// Close the stream controller
							streamController.close();
							streamController = null;
							streamClosed = true;
							return;
						}

						// Get new data from buffer since last processed position
						var newData = "";
						if (buffer && buffer.length > lastProcessedLength) {
							newData = buffer.substring(lastProcessedLength);
							lastProcessedLength = buffer.length;
						} else if (chunk && chunk.length > 0) {
							// Fallback to chunk if buffer tracking fails
							newData = chunk;
						}

						// Check for [DONE] marker in onchunk as additional fallback
						var isDoneInChunk = false;
						if (
							(newData && newData.indexOf("[DONE]") !== -1) ||
							(buffer && buffer.indexOf("[DONE]") !== -1)
						) {
							isDoneInChunk = true;
						}

						if (newData.length === 0) {
							// Still check for completion even with no new data
							if (isDoneInChunk && !streamClosed) {
								setTimeout(function () {
									if (!streamClosed && streamController) {
										streamController.close();
										streamController = null;
										streamClosed = true;
									}
								}, 50);
							}
							return;
						}

						// Encode and enqueue the new data immediately
						var encoder = new TextEncoder();
						var encodedData = encoder.encode(newData);
						streamController.enqueue(encodedData);

						// Force completion if we detected [DONE] marker
						if (isDoneInChunk && !streamClosed) {
							// Allow more time for all data to be processed
							setTimeout(function () {
								if (!streamClosed && streamController) {
									streamController.close();
									streamController = null;
									streamClosed = true;
								}
							}, 100); // Increased delay to allow buffer processing
						}
					};

					// Set up completion handler for streaming
					var originalOnload = xhr.onload;

					xhr.onload = function () {
						// Close the stream controller if it exists and hasn't been closed yet
						if (streamController && !streamClosed) {
							// Process any remaining buffer data
							if (
								xhr._streamingBuffer &&
								xhr._streamingBuffer.length > lastProcessedLength
							) {
								var finalData =
									xhr._streamingBuffer.substring(lastProcessedLength);
								var encoder = new TextEncoder();
								streamController.enqueue(encoder.encode(finalData));
							}

							streamController.close();
							streamController = null;
							streamClosed = true;
						}

						// Call original onload if it exists
						if (originalOnload) {
							originalOnload.call(xhr);
						}
					};

					// Only use monitoring as a fallback if onchunk is not available
					function monitorStreamingBuffer() {
						if (!streamController || aborted || xhr.onchunk) {
							// Stop monitoring if we have onchunk handler
							if (streamingCheckInterval) {
								clearInterval(streamingCheckInterval);
								streamingCheckInterval = null;
							}
							return;
						}

						if (xhr._streamingBuffer !== undefined) {
							var currentBufferLength = xhr._streamingBuffer.length;

							if (currentBufferLength > lastBufferLength) {
								// New data has arrived
								var newData = xhr._streamingBuffer.substring(lastBufferLength);
								lastBufferLength = currentBufferLength;

								// Encode and enqueue immediately
								var encoder = new TextEncoder();
								var encodedData = encoder.encode(newData);
								streamController.enqueue(encodedData);
							}
						}

						// Check if request is complete
						if (xhr.readyState === 4) {
							if (streamingCheckInterval) {
								clearInterval(streamingCheckInterval);
								streamingCheckInterval = null;
							}

							// Only close if not already closed
							if (!streamClosed) {
								// Process any remaining data
								if (
									xhr._streamingBuffer &&
									xhr._streamingBuffer.length > lastBufferLength
								) {
									var finalData =
										xhr._streamingBuffer.substring(lastBufferLength);
									if (finalData.trim()) {
										var encoder = new TextEncoder();
										streamController.enqueue(encoder.encode(finalData));
									}
								} else if (xhr._streamingBuffer && lastBufferLength === 0) {
									// Edge case: buffer exists but we never tracked it, send all data
									var encoder = new TextEncoder();
									streamController.enqueue(
										encoder.encode(xhr._streamingBuffer),
									);
								}
								streamController.close();
								streamClosed = true;
							}
						}
					}

					// Only start monitoring if onchunk is not available
					if (!xhr.onchunk) {
						streamingCheckInterval = setInterval(monitorStreamingBuffer, 50); // Check every 50ms
					}
				}
			}

			var responseResolved = false; // Track if response has been resolved

			xhr.onreadystatechange = function () {
				if (xhr.readyState === 2 && isStreamingEnabled && !responseResolved) {
					// HEADERS_RECEIVED - resolve streaming response immediately (only once)

					var options = {
						status: xhr.status,
						statusText: xhr.statusText,
						headers: new Headers(parseHeaders(xhr.getAllResponseHeaders())),
						url: request.url,
						body: stream,
					};

					responseResolved = true; // Mark as resolved
					resolve(new Response(null, options));
				}
			};

			xhr.onload = function () {
				if (request.signal) {
					request.signal.removeEventListener("abort", abortRequest);
				}

				// Clean up streaming
				if (streamingCheckInterval) {
					clearInterval(streamingCheckInterval);
					streamingCheckInterval = null;
				}

				if (aborted) return;

				if (!isStreamingEnabled) {
					// Regular non-streaming response
					var options = {
						status: xhr.status,
						statusText: xhr.statusText,
						headers: new Headers(parseHeaders(xhr.getAllResponseHeaders())),
						url: request.url,
					};

					var body = xhr.responseText;
					resolve(new Response(body, options));
				}
			};

			xhr.onerror = function () {
				if (request.signal) {
					request.signal.removeEventListener("abort", abortRequest);
				}

				if (aborted) return;

				console.error("❌ XMLHttpRequest error");
				if (streamController) {
					streamController.error(new TypeError("Network request failed"));
				}
				reject(new TypeError("Network request failed"));
			};

			xhr.ontimeout = function () {
				if (request.signal) {
					request.signal.removeEventListener("abort", abortRequest);
				}

				if (aborted) return;

				console.error("⏰ XMLHttpRequest timeout");
				if (streamController) {
					streamController.error(new TypeError("Network request timed out"));
				}
				reject(new TypeError("Network request timed out"));
			};

			// Helper function to parse headers string into object
			function parseHeaders(headersString) {
				var headers = {};
				if (!headersString) return headers;

				var lines = headersString.split("\n");
				for (var i = 0; i < lines.length; i++) {
					var line = lines[i].trim();
					if (line) {
						var colonIndex = line.indexOf(":");
						if (colonIndex > 0) {
							var name = line.substring(0, colonIndex).trim();
							var value = line.substring(colonIndex + 1).trim();
							headers[name] = value;
						}
					}
				}
				return headers;
			}

			// Handle FormData and body
			var body = request._bodyInit;
			if (body && support.formData && FormData.prototype.isPrototypeOf(body)) {
				if (body.polyfill && typeof body._asMultipart === "function") {
					const boundary = body._getBoundary();
					body = body._asMultipart(boundary);
				}
			}

			// Send XMLHttpRequest
			if (
				request.method === "GET" ||
				request.method === "HEAD" ||
				!body ||
				body === ""
			) {
				xhr.send();
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
