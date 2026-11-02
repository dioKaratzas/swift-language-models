/// What the API format targets, such as `ChatCompletionsAPI`, share: the changes a request makes to what the app asked
/// for, request metadata within its limits, the error object of OpenAI's formats, and the check for a host that rejects
/// a schema's constraints.
///
/// Providers never name these; a format's executor uses them for every provider it sends requests to.
package enum APIFormat {}
