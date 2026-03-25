// Kanchi Saree Catalog - Product Data & Application Logic

const products = [
    {
        id: 1,
        name: "Royal Magenta Bridal Kanchipuram",
        price: 45000,
        category: "bridal",
        description: "Pure mulberry silk bridal saree with heavy gold zari border and traditional temple motifs. Includes matching blouse piece.",
        weaveType: "Handloom",
        color: "Magenta & Gold",
        weight: "850g",
        rating: 4.8,
        tags: ["Pure Silk", "Bridal", "Silk Mark"],
        emoji: "\uD83D\uDC51"
    },
    {
        id: 2,
        name: "Emerald Green Wedding Pattu",
        price: 38000,
        category: "bridal",
        description: "Stunning emerald green Kanchipuram pattu saree with contrast maroon border and peacock motifs woven in real zari.",
        weaveType: "Handloom",
        color: "Emerald Green & Maroon",
        weight: "780g",
        rating: 4.7,
        tags: ["Pure Silk", "Bridal", "Zari Work"],
        emoji: "\uD83E\uDD9A"
    },
    {
        id: 3,
        name: "Navy Blue Contrast Border Silk",
        price: 22000,
        category: "wedding",
        description: "Elegant navy blue Kanchipuram silk with a contrasting orange-gold border. Perfect for wedding guest attire.",
        weaveType: "Handloom",
        color: "Navy Blue & Orange",
        weight: "650g",
        rating: 4.6,
        tags: ["Pure Silk", "Wedding Guest", "Contrast Border"],
        emoji: "\uD83C\uDF1F"
    },
    {
        id: 4,
        name: "Crimson Red Temple Border Saree",
        price: 52000,
        category: "bridal",
        description: "Classic crimson red bridal Kanchipuram with elaborate temple border design and buttas across the body. Heavy zari pallu.",
        weaveType: "Handloom",
        color: "Crimson Red & Gold",
        weight: "920g",
        rating: 4.9,
        tags: ["Pure Silk", "Bridal", "Temple Border"],
        emoji: "\uD83C\uDFDB\uFE0F"
    },
    {
        id: 5,
        name: "Teal Soft Silk Party Wear",
        price: 8500,
        category: "festive",
        description: "Lightweight teal soft silk Kanchipuram saree with silver zari checks. Ideal for festive occasions and parties.",
        weaveType: "Powerloom",
        color: "Teal & Silver",
        weight: "450g",
        rating: 4.3,
        tags: ["Soft Silk", "Festive", "Lightweight"],
        emoji: "\u2728"
    },
    {
        id: 6,
        name: "Purple Art Silk Casual Saree",
        price: 3500,
        category: "casual",
        description: "Beautiful purple art silk Kanchipuram-style saree with small buttas. Affordable everyday elegance.",
        weaveType: "Powerloom",
        color: "Purple & Gold",
        weight: "350g",
        rating: 4.1,
        tags: ["Art Silk", "Casual", "Budget"],
        emoji: "\uD83C\uDF38"
    },
    {
        id: 7,
        name: "Peach Pink Wedding Collection",
        price: 28000,
        category: "wedding",
        description: "Delicate peach pink Kanchipuram silk with traditional coin butta design and rich zari border. Elegant wedding guest choice.",
        weaveType: "Handloom",
        color: "Peach Pink & Gold",
        weight: "700g",
        rating: 4.5,
        tags: ["Pure Silk", "Wedding Guest", "Coin Butta"],
        emoji: "\uD83C\uDF3A"
    },
    {
        id: 8,
        name: "Mustard Yellow Festive Pattu",
        price: 15000,
        category: "festive",
        description: "Vibrant mustard yellow Kanchipuram pattu saree with maroon border and mango butta motifs. Perfect for Pongal and Diwali.",
        weaveType: "Handloom",
        color: "Mustard Yellow & Maroon",
        weight: "600g",
        rating: 4.4,
        tags: ["Pure Silk", "Festive", "Mango Butta"],
        emoji: "\uD83C\uDF1E"
    },
    {
        id: 9,
        name: "Coral Orange Art Silk Daily Wear",
        price: 4200,
        category: "casual",
        description: "Coral orange art silk saree with simple thread border. Comfortable for daily wear with Kanchipuram-style design elements.",
        weaveType: "Powerloom",
        color: "Coral Orange & Cream",
        weight: "380g",
        rating: 4.0,
        tags: ["Art Silk", "Daily Wear", "Comfortable"],
        emoji: "\uD83C\uDF3B"
    },
    {
        id: 10,
        name: "Ivory White Bridal Silk",
        price: 48000,
        category: "bridal",
        description: "Exquisite ivory white Kanchipuram bridal silk with full gold zari work and traditional checks. South Indian bridal classic.",
        weaveType: "Handloom",
        color: "Ivory White & Gold",
        weight: "880g",
        rating: 4.9,
        tags: ["Pure Silk", "Bridal", "Full Zari"],
        emoji: "\uD83D\uDC8D"
    },
    {
        id: 11,
        name: "Olive Green Festive Silk",
        price: 18000,
        category: "festive",
        description: "Rich olive green Kanchipuram silk with copper zari border. A unique color choice for temple visits and festive gatherings.",
        weaveType: "Handloom",
        color: "Olive Green & Copper",
        weight: "620g",
        rating: 4.5,
        tags: ["Pure Silk", "Festive", "Copper Zari"],
        emoji: "\uD83C\uDF3F"
    },
    {
        id: 12,
        name: "Sky Blue Cotton-Silk Casual",
        price: 5500,
        category: "casual",
        description: "Breathable sky blue cotton-silk blend with Kanchipuram-style temple border. Perfect for office wear and casual outings.",
        weaveType: "Powerloom",
        color: "Sky Blue & Silver",
        weight: "400g",
        rating: 4.2,
        tags: ["Cotton-Silk", "Casual", "Office Wear"],
        emoji: "\uD83C\uDF24\uFE0F"
    }
];

// Format currency in INR
function formatPrice(price) {
    return new Intl.NumberFormat('en-IN', {
        style: 'currency',
        currency: 'INR',
        maximumFractionDigits: 0
    }).format(price);
}

// Generate star rating HTML
function generateStars(rating) {
    const fullStars = Math.floor(rating);
    const hasHalf = rating % 1 >= 0.5;
    let stars = '';
    for (let i = 0; i < fullStars; i++) stars += '\u2605';
    if (hasHalf) stars += '\u2606';
    return stars + ' ' + rating.toFixed(1);
}

// Render a single product card
function renderProductCard(product) {
    return `
        <div class="product-card" data-category="${product.category}">
            <div class="product-image">${product.emoji}</div>
            <div class="product-info">
                <h3>${product.name}</h3>
                <div class="price">${formatPrice(product.price)}</div>
                <p class="description">${product.description}</p>
                <div class="product-tags">
                    ${product.tags.map(tag => `<span class="tag">${tag}</span>`).join('')}
                </div>
                <div class="product-meta">
                    <span class="weave-type">${product.weaveType} | ${product.weight}</span>
                    <span class="rating">${generateStars(product.rating)}</span>
                </div>
            </div>
        </div>
    `;
}

// Render all products
function renderProducts(filter = 'all') {
    const grid = document.getElementById('productGrid');
    const filtered = filter === 'all' ? products : products.filter(p => p.category === filter);
    grid.innerHTML = filtered.map(renderProductCard).join('');
}

// Filter button logic
document.querySelectorAll('.filter-btn').forEach(btn => {
    btn.addEventListener('click', () => {
        document.querySelectorAll('.filter-btn').forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        renderProducts(btn.dataset.filter);
    });
});

// Contact form handler
document.getElementById('contactForm').addEventListener('submit', function(e) {
    e.preventDefault();
    alert('Thank you for your message! We will get back to you within 24 hours.');
    this.reset();
});

// Smooth scroll for nav links
document.querySelectorAll('a[href^="#"]').forEach(anchor => {
    anchor.addEventListener('click', function(e) {
        e.preventDefault();
        const target = document.querySelector(this.getAttribute('href'));
        if (target) {
            target.scrollIntoView({ behavior: 'smooth', block: 'start' });
        }
    });
});

// Initial render
renderProducts();
