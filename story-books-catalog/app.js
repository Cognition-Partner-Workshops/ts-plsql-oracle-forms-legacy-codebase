// Story Books Catalog - Product Data & Application Logic

const books = [
    {
        id: 1,
        name: "365 Bedtime Stories and Rhymes",
        author: "Cottage Door Press",
        price: 12.99,
        category: "children",
        description: "A treasury of short bedtime stories, nursery rhymes, and fairy tales for children. Perfect for nightly read-aloud sessions with little ones.",
        format: "Hardcover",
        pages: 384,
        ageGroup: "Ages 2-6",
        rating: 4.5,
        tags: ["Bedtime", "Fairy Tales", "Bestseller"],
        emoji: "\uD83C\uDF19",
        bgColor: "#e8d5f5"
    },
    {
        id: 2,
        name: "The Jungle Book",
        author: "Rudyard Kipling",
        price: 6.27,
        category: "classic",
        description: "The timeless classic tale of Mowgli, a boy raised by wolves in the Indian jungle. Features beloved characters Baloo, Bagheera, and Shere Khan.",
        format: "Paperback",
        pages: 277,
        ageGroup: "Ages 8+",
        rating: 4.7,
        tags: ["Classic", "Adventure", "Animals"],
        emoji: "\uD83D\uDC05",
        bgColor: "#d4edda"
    },
    {
        id: 3,
        name: "Amazon Stories: Vol. 1",
        author: "Pedro & Lourenco",
        price: 18.00,
        category: "fiction",
        description: "A captivating collection of original stories exploring themes of discovery, wonder, and human connection. Beautifully illustrated anthology.",
        format: "Paperback",
        pages: 256,
        ageGroup: "Ages 12+",
        rating: 4.3,
        tags: ["Short Stories", "Anthology", "Illustrated"],
        emoji: "\uD83D\uDCD6",
        bgColor: "#d5e8f0"
    },
    {
        id: 4,
        name: "Stories from the Amazon",
        author: "Hector Pindle",
        price: 25.99,
        category: "fiction",
        description: "Enchanting tales inspired by the rich folklore and biodiversity of the Amazon rainforest. A journey into nature's most mysterious wilderness.",
        format: "Hardcover",
        pages: 312,
        ageGroup: "Ages 10+",
        rating: 4.4,
        tags: ["Nature", "Folklore", "Adventure"],
        emoji: "\uD83C\uDF3F",
        bgColor: "#c8e6c9"
    },
    {
        id: 5,
        name: "Disney Classic Storybook Collection",
        author: "Disney Press",
        price: 15.99,
        category: "children",
        description: "Bundle of 10 Disney bedtime story books featuring Disney Princess, Mickey, Minnie, and Winnie The Pooh. Perfect gift for toddlers.",
        format: "Hardcover",
        pages: 304,
        ageGroup: "Ages 3-7",
        rating: 4.8,
        tags: ["Disney", "Gift Set", "Bestseller"],
        emoji: "\uD83C\uDFF0",
        bgColor: "#fce4ec"
    },
    {
        id: 6,
        name: "The Amazon Call",
        author: "Various Authors",
        price: 26.35,
        category: "fiction",
        description: "Stories from the heart of the world's largest rainforest. A compelling anthology about people, nature, and the call of the wild.",
        format: "Paperback",
        pages: 288,
        ageGroup: "Adults",
        rating: 4.2,
        tags: ["Anthology", "Nature Writing", "Literary"],
        emoji: "\uD83C\uDF0D",
        bgColor: "#dcedc8"
    },
    {
        id: 7,
        name: "Sherlock Holmes: Complete Collection",
        author: "Arthur Conan Doyle",
        price: 14.99,
        category: "mystery",
        description: "All four novels and 56 short stories featuring the world's greatest detective. Includes A Study in Scarlet, The Hound of the Baskervilles, and more.",
        format: "Paperback",
        pages: 1408,
        ageGroup: "Ages 12+",
        rating: 4.9,
        tags: ["Detective", "Classic", "Complete Works"],
        emoji: "\uD83D\uDD0D",
        bgColor: "#fff3cd"
    },
    {
        id: 8,
        name: "Grimm's Fairy Tales",
        author: "Brothers Grimm",
        price: 9.99,
        category: "classic",
        description: "The complete collection of fairy tales by the Brothers Grimm including Cinderella, Rapunzel, Hansel and Gretel, Snow White, and many more timeless stories.",
        format: "Paperback",
        pages: 656,
        ageGroup: "Ages 8+",
        rating: 4.6,
        tags: ["Fairy Tales", "Classic", "Collection"],
        emoji: "\uD83E\uDDD9",
        bgColor: "#e1bee7"
    },
    {
        id: 9,
        name: "The Girl on the Train",
        author: "Paula Hawkins",
        price: 11.49,
        category: "mystery",
        description: "A riveting psychological thriller about Rachel, who becomes entangled in a missing persons investigation. A gripping page-turner you can't put down.",
        format: "Paperback",
        pages: 336,
        ageGroup: "Adults",
        rating: 4.1,
        tags: ["Thriller", "Suspense", "Bestseller"],
        emoji: "\uD83D\ude86",
        bgColor: "#cfd8dc"
    },
    {
        id: 10,
        name: "Charlotte's Web",
        author: "E.B. White",
        price: 7.99,
        category: "children",
        description: "The beloved story of friendship between Wilbur the pig and Charlotte the spider. A heartwarming classic that has touched millions of young readers.",
        format: "Paperback",
        pages: 192,
        ageGroup: "Ages 6-10",
        rating: 4.8,
        tags: ["Friendship", "Classic", "Award Winner"],
        emoji: "\uD83D\uDD77\uFE0F",
        bgColor: "#f0f4c3"
    },
    {
        id: 11,
        name: "Pride and Prejudice",
        author: "Jane Austen",
        price: 5.99,
        category: "classic",
        description: "Jane Austen's masterpiece of wit, romance, and social commentary. Follow Elizabeth Bennet as she navigates love and society in Regency-era England.",
        format: "Paperback",
        pages: 432,
        ageGroup: "Ages 14+",
        rating: 4.7,
        tags: ["Romance", "Classic", "Literary"],
        emoji: "\uD83C\uDFF5\uFE0F",
        bgColor: "#ffe0b2"
    },
    {
        id: 12,
        name: "And Then There Were None",
        author: "Agatha Christie",
        price: 9.99,
        category: "mystery",
        description: "Ten strangers are lured to a remote island, and one by one they begin to die. Agatha Christie's masterpiece and the world's best-selling mystery novel.",
        format: "Paperback",
        pages: 272,
        ageGroup: "Ages 14+",
        rating: 4.8,
        tags: ["Mystery", "Classic", "Bestseller"],
        emoji: "\uD83C\uDFDD\uFE0F",
        bgColor: "#b2dfdb"
    }
];

// Format currency in USD
function formatPrice(price) {
    return new Intl.NumberFormat('en-US', {
        style: 'currency',
        currency: 'USD'
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
function renderProductCard(book) {
    return `
        <div class="product-card" data-category="${book.category}">
            <div class="product-image" style="background: linear-gradient(135deg, ${book.bgColor}, #f5f0e8);">${book.emoji}</div>
            <div class="product-info">
                <h3>${book.name}</h3>
                <div class="author">by ${book.author}</div>
                <div class="price">${formatPrice(book.price)}</div>
                <p class="description">${book.description}</p>
                <div class="product-tags">
                    ${book.tags.map(tag => `<span class="tag">${tag}</span>`).join('')}
                </div>
                <div class="product-meta">
                    <span class="format">${book.format} | ${book.pages} pages | ${book.ageGroup}</span>
                    <span class="rating">${generateStars(book.rating)}</span>
                </div>
            </div>
        </div>
    `;
}

// Render all products
function renderProducts(filter = 'all') {
    const grid = document.getElementById('productGrid');
    const filtered = filter === 'all' ? books : books.filter(b => b.category === filter);
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
    alert('Thank you for your message! We will get back to you within 24 hours with book recommendations.');
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
