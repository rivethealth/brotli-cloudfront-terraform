function process(request, logs) {
  const checkBrotliHeaders = (request.origin.custom || request.origin.s3)
    .customHeaders['x-check-brotli'];
  const forbidBrotli =
    checkBrotliHeaders &&
    checkBrotliHeaders.some(({ value }) => value === 'false');
  logs.push(`Check brotli: ${!forbidBrotli}`);
  if (forbidBrotli) {
    return;
  }

  const acceptHeaders = request.headers['accept-encoding'];
  const acceptsBrotli =
    acceptHeaders &&
    acceptHeaders.some(({ value }) => value.split(/[\s,;]/).includes('br'));
  logs.push(`Accept brotli: ${acceptsBrotli}`);
  if (!acceptsBrotli) {
    return;
  }

  request.uri += '.br';
}

exports.handler = async ({
  Records: [
    {
      cf: { request },
    },
  ],
}) => {
  const logs = [];
  logs.push(`Original path: ${request.uri}`);
  process(request, logs);
  logs.push(`Final path: ${request.uri}`);
  console.log(logs.join('\n'));
  return request;
};
