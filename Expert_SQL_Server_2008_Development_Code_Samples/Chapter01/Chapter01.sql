--Subtype modeling: Not so good
CREATE TABLE Products
(
    UPC INT NOT NULL PRIMARY KEY,
    Weight DECIMAL NOT NULL,
    Price DECIMAL NOT NULL
);

CREATE TABLE Books
(
    UPC INT NOT NULL PRIMARY KEY
        REFERENCES Products (UPC),
    PageCount INT NOT NULL
);

CREATE TABLE DVDs
(
    UPC INT NOT NULL PRIMARY KEY
        REFERENCES Products (UPC),
    LengthInMinutes DECIMAL NOT NULL,
    Format VARCHAR(4) NOT NULL
        CHECK (Format IN ('NTSC', 'PAL'))
);
GO



--Better
CREATE TABLE Products
(
    UPC INT NOT NULL PRIMARY KEY,
    Weight DECIMAL NOT NULL,
    Price DECIMAL NOT NULL,
    ProductType CHAR(1) NOT NULL
        CHECK (ProductType IN ('B', 'D')),
    UNIQUE (UPC, ProductType)
);

CREATE TABLE Books
(
    UPC INT NOT NULL PRIMARY KEY,
    ProductType CHAR(1) NOT NULL
        CHECK (ProductType = 'B'),
    PageCount INT NOT NULL,
    FOREIGN KEY (UPC, ProductType) REFERENCES Products (UPC, ProductType)
);

CREATE TABLE DVDs
(
    UPC INT NOT NULL PRIMARY KEY,
    ProductType CHAR(1) NOT NULL
        CHECK (ProductType = 'D'),
    LengthInMinutes DECIMAL NOT NULL,
    Format VARCHAR(4) NOT NULL
        CHECK (Format IN ('NTSC', 'PAL')),
    FOREIGN KEY (UPC, ProductType) REFERENCES Products (UPC, ProductType)
);
GO