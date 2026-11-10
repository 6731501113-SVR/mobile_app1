const mysql = require("mysql2");
const con = mysql.createConnection({
   host: 'mysql-mobile-mobile-project-mfu.a.aivencloud.com',
   port: 20078,
   user: 'avnadmin',
   password: 'AVNS_3o4Uup1uH3_enXIl-ld',
   database: 'rentDB'
});


module.exports = con;