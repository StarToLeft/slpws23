describe("full flow", () => {
    it("Sing up, create new product", () => {
        cy.visit("localhost:4567");
        cy.contains('Register').click();
        cy.get('input').first().type('Melonsmurf');
        cy.get('input').eq(1).type('melonsmurf@epsidel.se');
        cy.get('input').eq(2).type('Katten123@');
        cy.get('input').eq(3).click();
        cy.contains('Login').click();

        cy.get('input').first().type('Melonsmurf');
        cy.get('input').eq(1).type('Katten123@');
        cy.get('input').eq(2).click();

        cy.contains('New product').click();
        cy.get('input').first().type('Test product');
        cy.get('textarea').first().type('Test description');
        cy.contains('Create Product').click();

        cy.contains('View').click();
        cy.contains("Place Bid").click();
        cy.get('input').first().type('100');
        cy.get("input").eq(1).click();
        cy.contains("Melonsmurf").should("exist");
    });
});
