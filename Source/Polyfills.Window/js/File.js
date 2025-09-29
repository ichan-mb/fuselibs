self = this;
(function (self) {
	"use strict";

	// File constructor
	self.File = function File(fileBits, fileName, options) {
		options = options || {};

		// If we already have a Blob polyfill, use it as the base
		if (self.Blob) {
			// Create a Blob with the file bits
			const blob = new self.Blob(fileBits, {
				type: options.type || "",
			});

			// Copy Blob properties and methods
			this.size = blob.size;
			this.type = blob.type;
			this._blobparts = blob._blobparts;

			// Copy Blob methods
			this.arrayBuffer = blob.arrayBuffer.bind(this);
			this.text = blob.text.bind(this);
			if (blob.stream) {
				this.stream = blob.stream.bind(this);
			}

			// File slice method
			this.slice = function (start, end, contentType) {
				const sliced = blob.slice(start, end, contentType);
				return new self.File([sliced], this.name, {
					type: contentType || this.type,
					lastModified: this.lastModified,
				});
			}.bind(this);
		} else {
			// Fallback implementation without Blob
			this.size = 0;
			this.type = options.type || "";
			this._blobparts = new Uint8Array(0);

			// Basic methods
			this.arrayBuffer = function () {
				return Promise.resolve(new ArrayBuffer(0));
			};

			this.text = function () {
				return Promise.resolve("");
			};

			this.slice = function (start, end, contentType) {
				return new self.File([], this.name, {
					type: contentType || this.type,
					lastModified: this.lastModified,
				});
			};
		}

		// File-specific properties
		this.name = String(fileName || "");
		this.lastModified = options.lastModified || Date.now();
	};

	// Make File inherit from Blob if available
	if (self.Blob) {
		self.File.prototype = Object.create(self.Blob.prototype);
		self.File.prototype.constructor = self.File;
	}

	// Mark as polyfill
	self.File.polyfill = true;

	// FileReader implementation
	self.FileReader = (function (FileReaderImpl) {
		"use strict";

		// FileReader constants
		const EMPTY = 0;
		const LOADING = 1;
		const DONE = 2;

		return function FileReader() {
			var self = this;

			// Properties
			self.readyState = EMPTY;
			self.result = null;
			self.error = null;

			// Event handlers
			self.onloadstart = null;
			self.onprogress = null;
			self.onload = null;
			self.onabort = null;
			self.onerror = null;
			self.onloadend = null;

			// Internal state
			var aborted = false;

			// Helper function to fire events
			function fireEvent(type, progressEvent) {
				const handler = self["on" + type];
				if (typeof handler === "function") {
					handler.call(self, progressEvent || { type: type });
				}
			}

			// Helper function to create ProgressEvent
			function createProgressEvent(type, loaded, total) {
				return {
					type: type,
					lengthComputable: total !== undefined && total >= 0,
					loaded: loaded || 0,
					total: total || 0,
					target: self,
				};
			}

			// Abort method
			self.abort = function () {
				if (self.readyState === LOADING) {
					aborted = true;
					self.readyState = DONE;
					self.result = null;
					fireEvent("abort");
					fireEvent("loadend");
				}
			};

			// Read as Data URL
			self.readAsDataURL = function (file) {
				if (self.readyState === LOADING) {
					throw new Error("FileReader already loading");
				}

				aborted = false;
				self.readyState = LOADING;
				self.result = null;
				self.error = null;

				fireEvent("loadstart");

				// Use native FileReaderImpl if available (Fuse-specific)
				if (FileReaderImpl && file.path) {
					FileReaderImpl.readAsDataURL(file.path)
						.then(function (base64) {
							if (aborted) return;

							self.readyState = DONE;
							self.result = base64;
							fireEvent("load");
							fireEvent("loadend");
						})
						.catch(function (error) {
							if (aborted) return;

							self.readyState = DONE;
							self.result = null;
							self.error = new Error("Failed to read file as data URL");
							fireEvent("error");
							fireEvent("loadend");
						});
				}
				// Use polyfill methods if file has them
				else if (file && typeof file.arrayBuffer === "function") {
					file
						.arrayBuffer()
						.then(function (arrayBuffer) {
							if (aborted) return;

							// Convert ArrayBuffer to base64 data URL
							const uint8Array = new Uint8Array(arrayBuffer);
							const binaryString = Array.from(uint8Array, (byte) =>
								String.fromCharCode(byte),
							).join("");
							const base64 = btoa(binaryString);
							const mimeType = file.type || "application/octet-stream";

							self.readyState = DONE;
							self.result = "data:" + mimeType + ";base64," + base64;
							fireEvent("load");
							fireEvent("loadend");
						})
						.catch(function (error) {
							if (aborted) return;

							self.readyState = DONE;
							self.result = null;
							self.error = new Error("Failed to read file as data URL");
							fireEvent("error");
							fireEvent("loadend");
						});
				} else {
					// Fallback for unsupported files
					setTimeout(function () {
						if (aborted) return;

						self.readyState = DONE;
						self.result = null;
						self.error = new Error("Unsupported file type for readAsDataURL");
						fireEvent("error");
						fireEvent("loadend");
					}, 0);
				}
			};

			// Read as Text
			self.readAsText = function (file, encoding) {
				if (self.readyState === LOADING) {
					throw new Error("FileReader already loading");
				}

				aborted = false;
				self.readyState = LOADING;
				self.result = null;
				self.error = null;
				encoding = encoding || "utf-8";

				fireEvent("loadstart");

				// Use native FileReaderImpl if available (Fuse-specific)
				if (FileReaderImpl && file.path) {
					FileReaderImpl.readAsText(file.path)
						.then(function (text) {
							if (aborted) return;

							self.readyState = DONE;
							self.result = text;
							fireEvent("load");
							fireEvent("loadend");
						})
						.catch(function (error) {
							if (aborted) return;

							self.readyState = DONE;
							self.result = null;
							self.error = new Error("Failed to read file as text");
							fireEvent("error");
							fireEvent("loadend");
						});
				}
				// Use polyfill methods if file has them
				else if (file && typeof file.text === "function") {
					file
						.text()
						.then(function (text) {
							if (aborted) return;

							self.readyState = DONE;
							self.result = text;
							fireEvent("load");
							fireEvent("loadend");
						})
						.catch(function (error) {
							if (aborted) return;

							self.readyState = DONE;
							self.result = null;
							self.error = new Error("Failed to read file as text");
							fireEvent("error");
							fireEvent("loadend");
						});
				} else {
					// Fallback for unsupported files
					setTimeout(function () {
						if (aborted) return;

						self.readyState = DONE;
						self.result = null;
						self.error = new Error("Unsupported file type for readAsText");
						fireEvent("error");
						fireEvent("loadend");
					}, 0);
				}
			};

			// Read as ArrayBuffer
			self.readAsArrayBuffer = function (file) {
				if (self.readyState === LOADING) {
					throw new Error("FileReader already loading");
				}

				aborted = false;
				self.readyState = LOADING;
				self.result = null;
				self.error = null;

				fireEvent("loadstart");

				if (file && typeof file.arrayBuffer === "function") {
					file
						.arrayBuffer()
						.then(function (arrayBuffer) {
							if (aborted) return;

							self.readyState = DONE;
							self.result = arrayBuffer;
							fireEvent("load");
							fireEvent("loadend");
						})
						.catch(function (error) {
							if (aborted) return;

							self.readyState = DONE;
							self.result = null;
							self.error = new Error("Failed to read file as ArrayBuffer");
							fireEvent("error");
							fireEvent("loadend");
						});
				}
				// Fallback: try to construct from _blobparts if available
				else if (file && file._blobparts) {
					try {
						let arrayBuffer;
						if (file._blobparts.buffer) {
							// If _blobparts is a TypedArray, get its underlying buffer
							arrayBuffer = file._blobparts.buffer.slice(
								file._blobparts.byteOffset,
								file._blobparts.byteOffset + file._blobparts.byteLength,
							);
						} else {
							// Create new ArrayBuffer and copy data
							arrayBuffer = new ArrayBuffer(file._blobparts.length);
							const view = new Uint8Array(arrayBuffer);
							for (let i = 0; i < file._blobparts.length; i++) {
								view[i] = file._blobparts[i];
							}
						}

						setTimeout(function () {
							if (aborted) return;

							self.readyState = DONE;
							self.result = arrayBuffer;
							fireEvent("load");
							fireEvent("loadend");
						}, 0);
					} catch (error) {
						setTimeout(function () {
							if (aborted) return;

							self.readyState = DONE;
							self.result = null;
							self.error = new Error("Failed to read file as ArrayBuffer");
							fireEvent("error");
							fireEvent("loadend");
						}, 0);
					}
				} else {
					// Fallback for unsupported files
					setTimeout(function () {
						if (aborted) return;

						self.readyState = DONE;
						self.result = null;
						self.error = new Error(
							"Unsupported file type for readAsArrayBuffer",
						);
						fireEvent("error");
						fireEvent("loadend");
					}, 0);
				}
			};

			// Read as Binary String (deprecated but sometimes needed)
			self.readAsBinaryString = function (file) {
				if (self.readyState === LOADING) {
					throw new Error("FileReader already loading");
				}

				aborted = false;
				self.readyState = LOADING;
				self.result = null;
				self.error = null;

				fireEvent("loadstart");

				// Convert via ArrayBuffer
				if (file && typeof file.arrayBuffer === "function") {
					file
						.arrayBuffer()
						.then(function (arrayBuffer) {
							if (aborted) return;

							const uint8Array = new Uint8Array(arrayBuffer);
							const binaryString = Array.from(uint8Array, (byte) =>
								String.fromCharCode(byte),
							).join("");

							self.readyState = DONE;
							self.result = binaryString;
							fireEvent("load");
							fireEvent("loadend");
						})
						.catch(function (error) {
							if (aborted) return;

							self.readyState = DONE;
							self.result = null;
							self.error = new Error("Failed to read file as binary string");
							fireEvent("error");
							fireEvent("loadend");
						});
				} else {
					setTimeout(function () {
						if (aborted) return;

						self.readyState = DONE;
						self.result = null;
						self.error = new Error(
							"Unsupported file type for readAsBinaryString",
						);
						fireEvent("error");
						fireEvent("loadend");
					}, 0);
				}
			};
		};
	})(typeof require !== "undefined" ? require("FuseJS/FileReaderImpl") : null);

	// FileReader constants
	self.FileReader.EMPTY = 0;
	self.FileReader.LOADING = 1;
	self.FileReader.DONE = 2;

	// Mark as polyfill
	self.FileReader.polyfill = true;
})(typeof self !== "undefined" ? self : this);
