/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  devServer: {
    proxy: {
      "/api": "https://rpc.sepolia.org",
    },
  },
};

module.exports = nextConfig;
