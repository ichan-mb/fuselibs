self = this;
(function (self) {
	"use strict";

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

	// Helper function to convert bytes to string
	function utf8BytesToString(bytes) {
		const chars = [];
		let i = 0;
		while (i < bytes.length) {
			let c = bytes[i];
			if (c < 128) {
				chars.push(String.fromCharCode(c));
				i++;
			} else if (c > 191 && c < 224) {
				chars.push(String.fromCharCode(((c & 31) << 6) | (bytes[i + 1] & 63)));
				i += 2;
			} else if (c > 239 && c < 365) {
				const u =
					((c & 7) << 18) |
					((bytes[i + 1] & 63) << 12) |
					((bytes[i + 2] & 63) << 6) |
					(bytes[i + 3] & 63);
				chars.push(
					String.fromCharCode(
						Math.floor((u - 0x10000) / 0x400) + 0xd800,
						((u - 0x10000) % 0x400) + 0xdc00,
					),
				);
				i += 4;
			} else {
				chars.push(
					String.fromCharCode(
						((c & 15) << 12) | ((bytes[i + 1] & 63) << 6) | (bytes[i + 2] & 63),
					),
				);
				i += 3;
			}
		}
		return chars.join("");
	}

	// Helper function to normalize MIME type
	function normalizeMimeType(type) {
		if (typeof type !== "string") return "";
		type = type.trim().toLowerCase();
		// Remove any parameters for validation
		const semicolonIndex = type.indexOf(";");
		if (semicolonIndex !== -1) {
			type = type.substring(0, semicolonIndex).trim();
		}
		// Basic MIME type validation
		if (!/^[a-z]+\/[a-z0-9][a-z0-9!#$&\-\^]*$/i.test(type)) {
			return "";
		}
		return type;
	}

	// Helper function to process blob parts
	function processBlobParts(blobParts) {
		const parts = [];
		let totalSize = 0;

		for (let i = 0; i < blobParts.length; i++) {
			const part = blobParts[i];
			let bytes;

			if (typeof part === "string") {
				bytes = stringToUtf8Bytes(part);
			} else if (part instanceof ArrayBuffer) {
				bytes = new Uint8Array(part);
			} else if (
				part &&
				typeof part.buffer !== "undefined" &&
				part.buffer instanceof ArrayBuffer
			) {
				// TypedArray
				bytes = new Uint8Array(part.buffer, part.byteOffset, part.byteLength);
			} else if (part && typeof part._blobparts !== "undefined") {
				// Another Blob
				bytes = part._blobparts;
			} else if (part && typeof part.arrayBuffer === "function") {
				// Blob-like object
				throw new TypeError("Async blob parts not supported in this polyfill");
			} else {
				// Convert to string and then to bytes
				bytes = stringToUtf8Bytes(String(part));
			}

			parts.push(bytes);
			totalSize += bytes.length;
		}

		// Combine all parts into a single Uint8Array
		const combined = new Uint8Array(totalSize);
		let offset = 0;
		for (let i = 0; i < parts.length; i++) {
			combined.set(parts[i], offset);
			offset += parts[i].length;
		}

		return combined;
	}

	self.Blob = function (blobParts, options) {
		// Handle the case where blobParts is not provided
		if (arguments.length === 0) {
			blobParts = [];
		}

		// Ensure blobParts is an array
		if (!Array.isArray(blobParts)) {
			blobParts = [blobParts];
		}

		// Process options
		options = options || {};
		const type = normalizeMimeType(options.type || "");

		// Process blob parts
		this._blobparts = processBlobParts(blobParts);
		this._options = options;

		// Set properties
		this.type = type;
		this.size = this._blobparts.length;

		// arrayBuffer method
		this.arrayBuffer = function () {
			return Promise.resolve(
				this._blobparts.buffer.slice(
					this._blobparts.byteOffset,
					this._blobparts.byteOffset + this._blobparts.byteLength,
				),
			);
		};

		// bytes method (non-standard but useful)
		this.bytes = function () {
			return Promise.resolve(new Uint8Array(this._blobparts));
		};

		// slice method
		this.slice = function (start, end, contentType) {
			start = start || 0;
			end = end || this.size;
			contentType = normalizeMimeType(contentType || "");

			// Handle negative indices
			if (start < 0) {
				start = Math.max(0, this.size + start);
			}
			if (end < 0) {
				end = Math.max(0, this.size + end);
			}

			// Clamp to valid range
			start = Math.min(start, this.size);
			end = Math.min(end, this.size);

			// Ensure start <= end
			if (start > end) {
				end = start;
			}

			const slicedData = this._blobparts.slice(start, end);
			return new self.Blob([slicedData], { type: contentType });
		};

		// text method
		this.text = function () {
			return new Promise((resolve) => {
				try {
					const text = utf8BytesToString(this._blobparts);
					resolve(text);
				} catch (error) {
					resolve(""); // Fallback for malformed UTF-8
				}
			});
		};

		// stream method (basic implementation)
		this.stream = function () {
			const bytes = this._blobparts;
			const chunkSize = 64 * 1024; // 64KB chunks
			let position = 0;

			return new ReadableStream({
				start: function (controller) {
					function pump() {
						if (position >= bytes.length) {
							controller.close();
							return;
						}

						const chunk = bytes.slice(
							position,
							Math.min(position + chunkSize, bytes.length),
						);
						controller.enqueue(chunk);
						position += chunk.length;
						pump();
					}
					pump();
				},
			});
		};
	};

	// Add static properties
	self.Blob.polyfill = true;

	// Add support for URL.createObjectURL and URL.revokeObjectURL if needed
	if (typeof self.URL === "undefined") {
		self.URL = {};
	}

	if (typeof self.URL.createObjectURL === "undefined") {
		const objectURLs = new Map();
		let urlCounter = 0;

		self.URL.createObjectURL = function (blob) {
			if (!(blob instanceof self.Blob)) {
				throw new TypeError(
					"Failed to execute 'createObjectURL' on 'URL': parameter 1 is not of type 'Blob'.",
				);
			}
			const url = "blob:" + self.location.origin + "/" + ++urlCounter;
			objectURLs.set(url, blob);
			return url;
		};

		self.URL.revokeObjectURL = function (url) {
			objectURLs.delete(url);
		};
	}
})(typeof self !== "undefined" ? self : this);
