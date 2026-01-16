// Script to generate PWA icons
// Run: node scripts/generate-icons.js

const fs = require('fs');
const path = require('path');
const sharp = require('sharp');

const sizes = [16, 32, 72, 96, 128, 144, 152, 180, 192, 384, 512];

// SVG template for RoundCaddy icon (golf flag/target design)
const createSvgIcon = () => `
<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">
  <defs>
    <linearGradient id="grad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#10b981"/>
      <stop offset="100%" style="stop-color:#3b82f6"/>
    </linearGradient>
  </defs>
  <!-- Background -->
  <rect width="512" height="512" rx="96" fill="url(#grad)"/>
  <!-- Golf flag pole -->
  <rect x="240" y="100" width="12" height="320" fill="white" rx="6"/>
  <!-- Flag -->
  <path d="M252 100 L252 200 L360 150 Z" fill="white"/>
  <!-- Golf hole -->
  <ellipse cx="246" cy="420" rx="80" ry="24" fill="rgba(255,255,255,0.3)"/>
  <!-- Ball -->
  <circle cx="320" cy="380" r="32" fill="white"/>
</svg>
`;

async function generateIcons() {
  // Create icons directory if it doesn't exist
  const iconsDir = path.join(__dirname, '../public/icons');
  if (!fs.existsSync(iconsDir)) {
    fs.mkdirSync(iconsDir, { recursive: true });
  }

  const svg = Buffer.from(createSvgIcon().trim());

  // Generate PNG icons for each size
  for (const size of sizes) {
    const filename = size === 180 
      ? 'apple-touch-icon.png' 
      : `icon-${size}x${size}.png`;
    
    await sharp(svg)
      .resize(size, size)
      .png()
      .toFile(path.join(iconsDir, filename));
    
    console.log(`Generated ${filename}`);
  }

  // Also save the original SVG
  fs.writeFileSync(path.join(iconsDir, 'icon.svg'), createSvgIcon().trim());
  console.log('Generated icon.svg');

  console.log('\n✅ All PWA icons generated successfully!');
}

generateIcons().catch(console.error);
