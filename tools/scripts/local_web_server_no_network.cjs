/* Next binds a numeric loopback address through dns.lookup. Permit only that
 * literal operation; retain the existing rejection of sockets, fetch and DNS. */
const dns=require('node:dns');
const lookup=dns.lookup.bind(dns);
const lookupAsync=dns.promises.lookup.bind(dns.promises);
require('./local_ops_rehearsal_no_network.cjs');
const deniedLookup=dns.lookup,deniedAsync=dns.promises.lookup;
const literal=host=>host==='127.0.0.1'||host==='::1';
dns.lookup=(host,...args)=>literal(host)?lookup(host,...args):deniedLookup(host,...args);
dns.promises.lookup=(host,...args)=>literal(host)?lookupAsync(host,...args):deniedAsync(host,...args);
