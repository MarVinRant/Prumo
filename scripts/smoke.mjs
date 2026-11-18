const baseUrl = process.argv[2] ?? 'https://prumo-stock-hml.marcosranti.workers.dev'
const routes = ['/', '/stock', '/events', '/purchases', '/reports', '/admin']

for (const route of routes) {
  const response = await fetch(`${baseUrl}${route}`)
  const contentType = response.headers.get('content-type') ?? ''
  if (!response.ok || !contentType.includes('text/html')) throw new Error(`${route}: ${response.status} ${contentType}`)
  console.log(`${route} ${response.status} ${contentType.split(';')[0]}`)
}
