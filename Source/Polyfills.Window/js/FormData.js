self = this;
(function (self) {
	"use strict";

	// Don't override native FormData if it exists and works properly
	if (self.FormData && self.FormData.prototype.entries) {
		// Test if native FormData works with Blob
		try {
			const testForm = new self.FormData();
			testForm.append("test", "value");
			if (testForm.get("test") === "value") {
				return; // Native FormData works fine
			}
		} catch (e) {
			// Native FormData is broken, continue with polyfill
		}
	}

	// Helper function to generate boundary string
	function generateBoundary() {
		let boundary = "----formdata-polyfill-" + Math.random().toString(16);
		return boundary;
	}

	// Helper function to encode field name for multipart
	function escapeQuotes(name) {
		return String(name).replace(/"/g, '\\"');
	}

	// Helper function to convert string to UTF-8 bytes
	function stringToUtf8Bytes(str) {
		const utf8 = [];
		for (let i = 0; i < str.length; i++) {
			let charcode = str.charCodeAt(i);
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
					0x10000 + (((charcode & 0x3ff) << 10) | (str.charCodeAt(i) & 0x3ff));
				utf8.push(
					0xf0 | (charcode >> 18),
					0x80 | ((charcode >> 12) & 0x3f),
					0x80 | ((charcode >> 6) & 0x3f),
					0x80 | (charcode & 0x3f),
				);
			}
		}
		return new Uint8Array(utf8);
	}

	// FormData constructor
	self.FormData = function FormData(form) {
		this._entries = [];

		// If form element is provided, populate from form
		if (form && form.nodeName === "FORM") {
			const elements = form.elements;
			for (let i = 0; i < elements.length; i++) {
				const element = elements[i];
				if (!element.name || element.disabled) continue;

				if (element.type === "file") {
					const files = element.files;
					if (files && files.length > 0) {
						for (let j = 0; j < files.length; j++) {
							this.append(element.name, files[j]);
						}
					} else {
						// Empty file input
						this.append(element.name, new self.File([], "", { type: "" }));
					}
				} else if (element.type === "checkbox" || element.type === "radio") {
					if (element.checked) {
						this.append(element.name, element.value);
					}
				} else if (element.type === "select-multiple") {
					const options = element.options;
					for (let j = 0; j < options.length; j++) {
						if (options[j].selected) {
							this.append(element.name, options[j].value);
						}
					}
				} else {
					this.append(element.name, element.value);
				}
			}
		}

		// Append method
		this.append = function (name, value, filename) {
			name = String(name);

			// Handle File/Blob objects
			if (value && typeof value === "object" && typeof value.constructor === "function") {
				if (value instanceof self.File) {
					// File object
					this._entries.push({
						name: name,
						value: value,
						filename: value.name || "blob",
						type: "file"
					});
					return;
				} else if (value instanceof self.Blob) {
					// Blob object
					const file = new self.File([value], filename || "blob", {
						type: value.type
					});
					this._entries.push({
						name: name,
						value: file,
						filename: filename || "blob",
						type: "file"
					});
					return;
				}
			}

			// Handle regular values
			this._entries.push({
				name: name,
				value: String(value),
				filename: undefined,
				type: "string"
			});
		};

		// Set method (replaces existing entries with same name)
		this.set = function (name, value, filename) {
			name = String(name);

			// Remove existing entries with the same name
			this._entries = this._entries.filter(entry => entry.name !== name);

			// Add the new entry
			this.append(name, value, filename);
		};

		// Get method
		this.get = function (name) {
			name = String(name);
			const entry = this._entries.find(entry => entry.name === name);
			return entry ? entry.value : null;
		};

		// GetAll method
		this.getAll = function (name) {
			name = String(name);
			return this._entries
				.filter(entry => entry.name === name)
				.map(entry => entry.value);
		};

		// Has method
		this.has = function (name) {
			name = String(name);
			return this._entries.some(entry => entry.name === name);
		};

		// Delete method
		this.delete = function (name) {
			name = String(name);
			this._entries = this._entries.filter(entry => entry.name !== name);
		};

		// Keys iterator
		this.keys = function () {
			const keys = this._entries.map(entry => entry.name);
			let index = 0;
			return {
				next: function () {
					if (index < keys.length) {
						return { value: keys[index++], done: false };
					}
					return { done: true };
				},
				[Symbol.iterator]: function () {
					return this;
				}
			};
		};

		// Values iterator
		this.values = function () {
			const values = this._entries.map(entry => entry.value);
			let index = 0;
			return {
				next: function () {
					if (index < values.length) {
						return { value: values[index++], done: false };
					}
					return { done: true };
				},
				[Symbol.iterator]: function () {
					return this;
				}
			};
		};

		// Entries iterator
		this.entries = function () {
			const entries = this._entries.map(entry => [entry.name, entry.value]);
			let index = 0;
			return {
				next: function () {
					if (index < entries.length) {
						return { value: entries[index++], done: false };
					}
					return { done: true };
				},
				[Symbol.iterator]: function () {
					return this;
				}
			};
		};

		// forEach method
		this.forEach = function (callback, thisArg) {
			for (let i = 0; i < this._entries.length; i++) {
				const entry = this._entries[i];
				callback.call(thisArg, entry.value, entry.name, this);
			}
		};

		// toString method for form encoding
		this.toString = function () {
			const pairs = [];
			for (let i = 0; i < this._entries.length; i++) {
				const entry = this._entries[i];
				if (entry.type === "string") {
					pairs.push(
						encodeURIComponent(entry.name) + "=" + encodeURIComponent(entry.value)
					);
				}
			}
			return pairs.join("&");
		};

		// Internal method to convert to multipart data
		this._asMultipart = function (boundary) {
			const chunks = [];
			const encoder = stringToUtf8Bytes;
			const crlf = encoder("\r\n");

			for (let i = 0; i < this._entries.length; i++) {
				const entry = this._entries[i];

				// Boundary
				chunks.push(encoder("--" + boundary + "\r\n"));

				// Content-Disposition header
				let disposition = 'Content-Disposition: form-data; name="' + escapeQuotes(entry.name) + '"';

				if (entry.type === "file" && entry.value instanceof self.File) {
					disposition += '; filename="' + escapeQuotes(entry.filename || entry.value.name || "blob") + '"';
					chunks.push(encoder(disposition + "\r\n"));

					// Content-Type header
					const contentType = entry.value.type || "application/octet-stream";
					chunks.push(encoder("Content-Type: " + contentType + "\r\n\r\n"));

					// File content
					if (entry.value._blobparts) {
						chunks.push(entry.value._blobparts);
					} else {
						// Fallback for native File objects
						chunks.push(encoder("[File content not accessible in polyfill]"));
					}
				} else {
					chunks.push(encoder(disposition + "\r\n\r\n"));
					// String content
					chunks.push(encoder(String(entry.value)));
				}

				chunks.push(crlf);
			}

			// Final boundary
			chunks.push(encoder("--" + boundary + "--\r\n"));

			// Calculate total length
			let totalLength = 0;
			for (let i = 0; i < chunks.length; i++) {
				totalLength += chunks[i].length;
			}

			// Combine chunks
			const result = new Uint8Array(totalLength);
			let offset = 0;
			for (let i = 0; i < chunks.length; i++) {
				result.set(chunks[i], offset);
				offset += chunks[i].length;
			}

			return result;
		};

		// Internal method to get boundary
		this._getBoundary = function () {
			if (!this._boundary) {
				this._boundary = generateBoundary();
			}
			return this._boundary;
		};

		// Make it iterable (for...of support)
		if (typeof Symbol !== "undefined" && Symbol.iterator) {
			this[Symbol.iterator] = this.entries;
		}
	};

	// Static method to check if object is FormData
	self.FormData.prototype.constructor = self.FormData;

	// Mark as polyfill
	self.FormData.polyfill = true;

	// Ensure File polyfill exists for FormData to work properly
	if (!self.File && self.Blob) {
		self.File = function File(fileBits, fileName, options) {
			options = options || {};

			// Create a Blob with the file bits
			const blob = new self.Blob(fileBits, {
				type: options.type || ""
			});

			// Copy Blob properties and methods
			this.size = blob.size;
			this.type = blob.type;
			this._blobparts = blob._blobparts;

			// File-specific properties
			this.name = String(fileName || "");
			this.lastModified = options.lastModified || Date.now();

			// Copy Blob methods
			this.arrayBuffer = blob.arrayBuffer.bind(this);
			this.text = blob.text.bind(this);
			this.slice = function(start, end, contentType) {
				const sliced = blob.slice(start, end, contentType);
				return new self.File([sliced], this.name, {
					type: contentType || this.type,
					lastModified: this.lastModified
				});
			}.bind(this);

			if (blob.stream) {
				this.stream = blob.stream.bind(this);
			}
		};

		// Make File inherit from Blob
		if (self.Blob) {
			self.File.prototype = Object.create(self.Blob.prototype);
			self.File.prototype.constructor = self.File;
		}

		self.File.polyfill = true;
	}

})(typeof self !== "undefined" ? self : this);
