var Web3 = require("web3");
var SolidityEvent = require("web3/lib/web3/event.js");

(function() {
  // Planned for future features, logging, etc.
  function Provider(provider) {
    this.provider = provider;
  }

  Provider.prototype.send = function() {
    this.provider.send.apply(this.provider, arguments);
  };

  Provider.prototype.sendAsync = function() {
    this.provider.sendAsync.apply(this.provider, arguments);
  };

  var BigNumber = (new Web3()).toBigNumber(0).constructor;

  var Utils = {
    is_object: function(val) {
      return typeof val == "object" && !Array.isArray(val);
    },
    is_big_number: function(val) {
      if (typeof val != "object") return false;

      // Instanceof won't work because we have multiple versions of Web3.
      try {
        new BigNumber(val);
        return true;
      } catch (e) {
        return false;
      }
    },
    merge: function() {
      var merged = {};
      var args = Array.prototype.slice.call(arguments);

      for (var i = 0; i < args.length; i++) {
        var object = args[i];
        var keys = Object.keys(object);
        for (var j = 0; j < keys.length; j++) {
          var key = keys[j];
          var value = object[key];
          merged[key] = value;
        }
      }

      return merged;
    },
    promisifyFunction: function(fn, C) {
      var self = this;
      return function() {
        var instance = this;

        var args = Array.prototype.slice.call(arguments);
        var tx_params = {};
        var last_arg = args[args.length - 1];

        // It's only tx_params if it's an object and not a BigNumber.
        if (Utils.is_object(last_arg) && !Utils.is_big_number(last_arg)) {
          tx_params = args.pop();
        }

        tx_params = Utils.merge(C.class_defaults, tx_params);

        return new Promise(function(accept, reject) {
          var callback = function(error, result) {
            if (error != null) {
              reject(error);
            } else {
              accept(result);
            }
          };
          args.push(tx_params, callback);
          fn.apply(instance.contract, args);
        });
      };
    },
    synchronizeFunction: function(fn, instance, C) {
      var self = this;
      return function() {
        var args = Array.prototype.slice.call(arguments);
        var tx_params = {};
        var last_arg = args[args.length - 1];

        // It's only tx_params if it's an object and not a BigNumber.
        if (Utils.is_object(last_arg) && !Utils.is_big_number(last_arg)) {
          tx_params = args.pop();
        }

        tx_params = Utils.merge(C.class_defaults, tx_params);

        return new Promise(function(accept, reject) {

          var decodeLogs = function(logs) {
            return logs.map(function(log) {
              var logABI = C.events[log.topics[0]];

              if (logABI == null) {
                return null;
              }

              var decoder = new SolidityEvent(null, logABI, instance.address);
              return decoder.decode(log);
            }).filter(function(log) {
              return log != null;
            });
          };

          var callback = function(error, tx) {
            if (error != null) {
              reject(error);
              return;
            }

            var timeout = C.synchronization_timeout || 240000;
            var start = new Date().getTime();

            var make_attempt = function() {
              C.web3.eth.getTransactionReceipt(tx, function(err, receipt) {
                if (err) return reject(err);

                if (receipt != null) {
                  // If they've opted into next gen, return more information.
                  if (C.next_gen == true) {
                    return accept({
                      tx: tx,
                      receipt: receipt,
                      logs: decodeLogs(receipt.logs)
                    });
                  } else {
                    return accept(tx);
                  }
                }

                if (timeout > 0 && new Date().getTime() - start > timeout) {
                  return reject(new Error("Transaction " + tx + " wasn't processed in " + (timeout / 1000) + " seconds!"));
                }

                setTimeout(make_attempt, 1000);
              });
            };

            make_attempt();
          };

          args.push(tx_params, callback);
          fn.apply(self, args);
        });
      };
    }
  };

  function instantiate(instance, contract) {
    instance.contract = contract;
    var constructor = instance.constructor;

    // Provision our functions.
    for (var i = 0; i < instance.abi.length; i++) {
      var item = instance.abi[i];
      if (item.type == "function") {
        if (item.constant == true) {
          instance[item.name] = Utils.promisifyFunction(contract[item.name], constructor);
        } else {
          instance[item.name] = Utils.synchronizeFunction(contract[item.name], instance, constructor);
        }

        instance[item.name].call = Utils.promisifyFunction(contract[item.name].call, constructor);
        instance[item.name].sendTransaction = Utils.promisifyFunction(contract[item.name].sendTransaction, constructor);
        instance[item.name].request = contract[item.name].request;
        instance[item.name].estimateGas = Utils.promisifyFunction(contract[item.name].estimateGas, constructor);
      }

      if (item.type == "event") {
        instance[item.name] = contract[item.name];
      }
    }

    instance.allEvents = contract.allEvents;
    instance.address = contract.address;
    instance.transactionHash = contract.transactionHash;
  };

  // Use inheritance to create a clone of this contract,
  // and copy over contract's static functions.
  function mutate(fn) {
    var temp = function Clone() { return fn.apply(this, arguments); };

    Object.keys(fn).forEach(function(key) {
      temp[key] = fn[key];
    });

    temp.prototype = Object.create(fn.prototype);
    bootstrap(temp);
    return temp;
  };

  function bootstrap(fn) {
    fn.web3 = new Web3();
    fn.class_defaults  = fn.prototype.defaults || {};

    // Set the network iniitally to make default data available and re-use code.
    // Then remove the saved network id so the network will be auto-detected on first use.
    fn.setNetwork("default");
    fn.network_id = null;
    return fn;
  };

  // Accepts a contract object created with web3.eth.contract.
  // Optionally, if called without `new`, accepts a network_id and will
  // create a new version of the contract abstraction with that network_id set.
  function Contract() {
    if (this instanceof Contract) {
      instantiate(this, arguments[0]);
    } else {
      var C = mutate(Contract);
      var network_id = arguments.length > 0 ? arguments[0] : "default";
      C.setNetwork(network_id);
      return C;
    }
  };

  Contract.currentProvider = null;

  Contract.setProvider = function(provider) {
    var wrapped = new Provider(provider);
    this.web3.setProvider(wrapped);
    this.currentProvider = provider;
  };

  Contract.new = function() {
    if (this.currentProvider == null) {
      throw new Error("SmartRepository error: Please call setProvider() first before calling new().");
    }

    var args = Array.prototype.slice.call(arguments);

    if (!this.unlinked_binary) {
      throw new Error("SmartRepository error: contract binary not set. Can't deploy new instance.");
    }

    var regex = /__[^_]+_+/g;
    var unlinked_libraries = this.binary.match(regex);

    if (unlinked_libraries != null) {
      unlinked_libraries = unlinked_libraries.map(function(name) {
        // Remove underscores
        return name.replace(/_/g, "");
      }).sort().filter(function(name, index, arr) {
        // Remove duplicates
        if (index + 1 >= arr.length) {
          return true;
        }

        return name != arr[index + 1];
      }).join(", ");

      throw new Error("SmartRepository contains unresolved libraries. You must deploy and link the following libraries before you can deploy a new version of SmartRepository: " + unlinked_libraries);
    }

    var self = this;

    return new Promise(function(accept, reject) {
      var contract_class = self.web3.eth.contract(self.abi);
      var tx_params = {};
      var last_arg = args[args.length - 1];

      // It's only tx_params if it's an object and not a BigNumber.
      if (Utils.is_object(last_arg) && !Utils.is_big_number(last_arg)) {
        tx_params = args.pop();
      }

      tx_params = Utils.merge(self.class_defaults, tx_params);

      if (tx_params.data == null) {
        tx_params.data = self.binary;
      }

      // web3 0.9.0 and above calls new twice this callback twice.
      // Why, I have no idea...
      var intermediary = function(err, web3_instance) {
        if (err != null) {
          reject(err);
          return;
        }

        if (err == null && web3_instance != null && web3_instance.address != null) {
          accept(new self(web3_instance));
        }
      };

      args.push(tx_params, intermediary);
      contract_class.new.apply(contract_class, args);
    });
  };

  Contract.at = function(address) {
    if (address == null || typeof address != "string" || address.length != 42) {
      throw new Error("Invalid address passed to SmartRepository.at(): " + address);
    }

    var contract_class = this.web3.eth.contract(this.abi);
    var contract = contract_class.at(address);

    return new this(contract);
  };

  Contract.deployed = function() {
    if (!this.address) {
      throw new Error("Cannot find deployed address: SmartRepository not deployed or address not set.");
    }

    return this.at(this.address);
  };

  Contract.defaults = function(class_defaults) {
    if (this.class_defaults == null) {
      this.class_defaults = {};
    }

    if (class_defaults == null) {
      class_defaults = {};
    }

    var self = this;
    Object.keys(class_defaults).forEach(function(key) {
      var value = class_defaults[key];
      self.class_defaults[key] = value;
    });

    return this.class_defaults;
  };

  Contract.extend = function() {
    var args = Array.prototype.slice.call(arguments);

    for (var i = 0; i < arguments.length; i++) {
      var object = arguments[i];
      var keys = Object.keys(object);
      for (var j = 0; j < keys.length; j++) {
        var key = keys[j];
        var value = object[key];
        this.prototype[key] = value;
      }
    }
  };

  Contract.all_networks = {
  "default": {
    "abi": [
      {
        "constant": true,
        "inputs": [
          {
            "name": "amount",
            "type": "uint256"
          }
        ],
        "name": "calcPenalty",
        "outputs": [
          {
            "name": "",
            "type": "uint256"
          }
        ],
        "payable": false,
        "type": "function"
      },
      {
        "constant": true,
        "inputs": [],
        "name": "activeCommitHash",
        "outputs": [
          {
            "name": "",
            "type": "bytes32"
          }
        ],
        "payable": false,
        "type": "function"
      },
      {
        "constant": false,
        "inputs": [],
        "name": "registerDev",
        "outputs": [],
        "payable": true,
        "type": "function"
      },
      {
        "constant": false,
        "inputs": [
          {
            "name": "myId",
            "type": "bytes32"
          },
          {
            "name": "result",
            "type": "string"
          }
        ],
        "name": "__callback",
        "outputs": [],
        "payable": false,
        "type": "function"
      },
      {
        "constant": false,
        "inputs": [
          {
            "name": "commitHash",
            "type": "bytes32"
          },
          {
            "name": "issueUrl",
            "type": "string"
          },
          {
            "name": "commitUrl",
            "type": "string"
          }
        ],
        "name": "submitCommit",
        "outputs": [],
        "payable": false,
        "type": "function"
      },
      {
        "constant": true,
        "inputs": [],
        "name": "url",
        "outputs": [
          {
            "name": "",
            "type": "string"
          }
        ],
        "payable": false,
        "type": "function"
      },
      {
        "constant": true,
        "inputs": [],
        "name": "activeDev",
        "outputs": [
          {
            "name": "",
            "type": "address"
          }
        ],
        "payable": false,
        "type": "function"
      },
      {
        "constant": true,
        "inputs": [],
        "name": "activeIssueUrl",
        "outputs": [
          {
            "name": "",
            "type": "string"
          }
        ],
        "payable": false,
        "type": "function"
      },
      {
        "constant": true,
        "inputs": [],
        "name": "penaltyDenom",
        "outputs": [
          {
            "name": "",
            "type": "uint256"
          }
        ],
        "payable": false,
        "type": "function"
      },
      {
        "constant": true,
        "inputs": [],
        "name": "penaltyNum",
        "outputs": [
          {
            "name": "",
            "type": "uint256"
          }
        ],
        "payable": false,
        "type": "function"
      },
      {
        "constant": false,
        "inputs": [
          {
            "name": "url",
            "type": "string"
          },
          {
            "name": "id",
            "type": "uint256"
          }
        ],
        "name": "fundIssue",
        "outputs": [],
        "payable": true,
        "type": "function"
      },
      {
        "constant": true,
        "inputs": [],
        "name": "minCollateral",
        "outputs": [
          {
            "name": "",
            "type": "uint256"
          }
        ],
        "payable": false,
        "type": "function"
      },
      {
        "constant": true,
        "inputs": [
          {
            "name": "",
            "type": "address"
          }
        ],
        "name": "collaterals",
        "outputs": [
          {
            "name": "",
            "type": "uint256"
          }
        ],
        "payable": false,
        "type": "function"
      },
      {
        "constant": true,
        "inputs": [
          {
            "name": "url",
            "type": "string"
          }
        ],
        "name": "getIssueByUrl",
        "outputs": [
          {
            "name": "",
            "type": "string"
          },
          {
            "name": "",
            "type": "uint256"
          },
          {
            "name": "",
            "type": "uint256"
          }
        ],
        "payable": false,
        "type": "function"
      },
      {
        "inputs": [
          {
            "name": "_url",
            "type": "string"
          },
          {
            "name": "_minCollateral",
            "type": "uint256"
          },
          {
            "name": "_penaltyNum",
            "type": "uint256"
          },
          {
            "name": "_penaltyDenom",
            "type": "uint256"
          }
        ],
        "type": "constructor"
      }
    ],
    "unlinked_binary": "0x6060604052604051610f26380380610f2683398101604052805160805160a05160c0519290930192909160008054600160a060020a031916737c2b639ae051fdaeecc2f8692911627020304ae217815584516004805492819052916020601f6002600019600185161561010002019093169290920482018190047f8a35acfbc15ff81a39ae7d344fd709f28e8600b4aa8c65c6b64bfe7fe36bd19b908101939290918901908390106100d457805160ff19168380011785555b506101049291505b8082111561012157600081556001016100c0565b828001600101855582156100b8579182015b828111156100b85782518260005055916020019190600101906100e6565b505060059290925560065560075550610e01806101256000396000f35b509056606060405236156100ae5760e060020a600035046308cd423381146100b35780631781fe32146100d85780631c32c5e8146100e657806327dc297e146100f85780633fd3fe96146101765780635600f04f146102285780635e7b11ba1461028d5780636a89097a146102a45780637742eb95146103095780638ecbfe4514610317578063b86147f914610325578063ba2de9bc1461040a578063eeb97d3b14610418578063fb28f55714610435575b610002565b34610002576105dd6004356007546006546000919083028115610002570490506106fb565b34610002576105dd60095481565b6105ef60055434101561070057610002565b346100025760408051602060046024803582810135601f81018590048502860185019096528585526105ef9583359593946044949392909201918190840183828082843750949650505050505050600854604051600160a060020a039091169060009060019082818181858883f19350505050151561071d57610002565b346100025760408051602060046024803582810135601f81018590048502860185019096528585526105ef9583359593946044949392909201918190840183828082843750506040805160209735808a0135601f81018a90048a0283018a019093528282529698976064979196506024919091019450909250829150840183828082843750949650505050505050600160a060020a033316600090815260036020526040902054151561072157610002565b34610002576105f160048054604080516020601f600260001961010060018816150201909516949094049384018190048102820181019092528281529291908301828280156109525780601f1061092757610100808354040283529160200191610952565b346100025761065f600854600160a060020a031681565b34610002576105f1600a8054604080516020601f600260001961010060018816150201909516949094049384018190048102820181019092528281529291908301828280156109525780601f1061092757610100808354040283529160200191610952565b34610002576105dd60075481565b34610002576105dd60065481565b6105ef6004808035906020019082018035906020019191908080601f01602080910402602001604051908101604052809392919081815260200183838082843750949650509335935050505081600260005083604051808280519060200190808383829060006004602084601f0104600302600f01f15090500191505090815260200160405180910390206000506000016000509080519060200190828054600181600116156101000203166002900490600052602060002090601f016020900481019282601f1061095a57805160ff19168380011785555b5061098a9291506107b4565b34610002576105dd60055481565b34610002576105dd60043560036020526000908152604090205481565b346100025761067b6004808035906020019082018035906020019191908080601f01602080910402602001604051908101604052809392919081815260200183838082843750949650505050505050602060405190810160405280600081526020015060006000600260005084604051808280519060200190808383829060006004602084601f0104600302600f01f1509050019150509081526020016040518091039020600050600001600050600260005085604051808280519060200190808383829060006004602084601f0104600302600f01f150905001915050908152602001604051809103902060005060010160005054600260005086604051808280519060200190808383829060006004602084601f0104600302600f01f150905001915050908152602001604051809103902060005060020160005054828054600181600116156101000203166002900480601f016020809104026020016040519081016040528092919081815260200182805460018160011615610100020316600290048015610a5b5780601f10610a3057610100808354040283529160200191610a5b565b60408051918252519081900360200190f35b005b60405180806020018281038252838181518152602001915080519060200190808383829060006004602084601f0104600302600f01f150905090810190601f1680156106515780820380516001836020036101000a031916815260200191505b509250505060405180910390f35b60408051600160a060020a039092168252519081900360200190f35b60405180806020018481526020018381526020018281038252858181518152602001915080519060200190808383829060006004602084601f0104600302600f01f150905090810190601f1680156106e75780820380516001836020036101000a031916815260200191505b5094505050505060405180910390f35b5060005b919050565b600160a060020a0333166000908152600360205260409020349055565b5050565b60088054600160a060020a0319166c01000000000000000000000000338102041790558151600a8054600082905290917fc65a7bb8d6351c1cf70c95a316cc6a92839c986682d98bc35f958f4883f9d2a8602060026101006001861615026000190190941693909304601f9081018490048201938701908390106107c857805160ff19168380011785555b506107f89291505b8082111561091d57600081556001016107b4565b828001600101855582156107ac579182015b828111156107ac5782518260005055916020019190600101906107da565b50506009839055604080518082018252600381527f55524c0000000000000000000000000000000000000000000000000000000000602080830191909152825160a081018452607081527f6a736f6e2868747470733a2f2f6170692e6769746875622e636f6d2f7265706f918101919091527f732f796f6e646f6e66752f32314d61726b6574706c616365437261776c65722f928101929092527f636f6d6d6974732f33303830633537363161626332636337663965353538316260608301527f6362626330666534393631292e73686100000000000000000000000000000000608083015261092191600080548190600160a060020a03161515610a7157610a6f600060006000610d27731d3b2638a7cc9f2cb3d298a3da7a90b67e5506ed5b3b90565b5090565b50505050565b820191906000526020600020905b81548152906001019060200180831161093557829003601f168201915b505050505081565b828001600101855582156103fe579182015b828111156103fe57825182600050559160200191906001019061096c565b505080600260005083604051808280519060200190808383829060006004602084601f0104600302600f01f15090500191505090815260200160405180910390206000506001016000508190555034600260005083604051808280519060200190808383829060006004602084601f0104600302600f01f15090500191505090815260200160405180910390206000506002016000828282505401925050819055505050565b820191906000526020600020905b815481529060010190602001808311610a3e57829003601f168201915b505050505092509250925092509193909250565b505b600060009054906101000a9004600160a060020a0316600160a060020a03166338cc48316000604051602001526040518160e060020a028152600401809050602060405180830381600087803b156100025760325a03f1156100025750505060405180519060200150600160006101000a815481600160a060020a0302191690836c01000000000000000000000000908102040217905550600160009054906101000a9004600160a060020a0316600160a060020a031663524f3889856000604051602001526040518260e060020a02815260040180806020018281038252838181518152602001915080519060200190808383829060006004602084601f0104600302600f01f150905090810190601f168015610ba35780820380516001836020036101000a031916815260200191505b5092505050602060405180830381600087803b156100025760325a03f11561000257505060405151915050670de0b6b3a764000062030d403a0201811115610bf157600091505b5092915050565b600160009054906101000a9004600160a060020a0316600160a060020a031663adf59f9982600087876000604051602001526040518560e060020a0281526004018084815260200180602001806020018381038352858181518152602001915080519060200190808383829060006004602084601f0104600302600f01f150905090810190601f168015610c995780820380516001836020036101000a031916815260200191505b508381038252848181518152602001915080519060200190808383829060006004602084601f0104600302600f01f150905090810190601f168015610cf25780820380516001836020036101000a031916815260200191505b50955050505050506020604051808303818588803b156100025761235a5a03f115610002575050604051519350610bea915050565b1115610d5b575060008054600160a060020a031916731d3b2638a7cc9f2cb3d298a3da7a90b67e5506ed17905560016106fb565b6000610d7a73c03a2615d5efaf5f49f60b7bb6583eaec212fdf1610919565b1115610dae575060008054600160a060020a03191673c03a2615d5efaf5f49f60b7bb6583eaec212fdf117905560016106fb565b6000610dcd7351efaf4c8b3c9afbd5ab9f4bbc82784ab6ef8faa610919565b11156106f7575060008054600160a060020a0319167351efaf4c8b3c9afbd5ab9f4bbc82784ab6ef8faa17905560016106fb56",
    "events": {},
    "updated_at": 1481742083357,
    "links": {},
    "address": "0xc4d3ee37798187dcab8237640b693a4f28b39be2"
  }
};

  Contract.checkNetwork = function(callback) {
    var self = this;

    if (this.network_id != null) {
      return callback();
    }

    this.web3.version.network(function(err, result) {
      if (err) return callback(err);

      var network_id = result.toString();

      // If we have the main network,
      if (network_id == "1") {
        var possible_ids = ["1", "live", "default"];

        for (var i = 0; i < possible_ids.length; i++) {
          var id = possible_ids[i];
          if (Contract.all_networks[id] != null) {
            network_id = id;
            break;
          }
        }
      }

      if (self.all_networks[network_id] == null) {
        return callback(new Error(self.name + " error: Can't find artifacts for network id '" + network_id + "'"));
      }

      self.setNetwork(network_id);
      callback();
    })
  };

  Contract.setNetwork = function(network_id) {
    var network = this.all_networks[network_id] || {};

    this.abi             = this.prototype.abi             = network.abi;
    this.unlinked_binary = this.prototype.unlinked_binary = network.unlinked_binary;
    this.address         = this.prototype.address         = network.address;
    this.updated_at      = this.prototype.updated_at      = network.updated_at;
    this.links           = this.prototype.links           = network.links || {};
    this.events          = this.prototype.events          = network.events || {};

    this.network_id = network_id;
  };

  Contract.networks = function() {
    return Object.keys(this.all_networks);
  };

  Contract.link = function(name, address) {
    if (typeof name == "function") {
      var contract = name;

      if (contract.address == null) {
        throw new Error("Cannot link contract without an address.");
      }

      Contract.link(contract.contract_name, contract.address);

      // Merge events so this contract knows about library's events
      Object.keys(contract.events).forEach(function(topic) {
        Contract.events[topic] = contract.events[topic];
      });

      return;
    }

    if (typeof name == "object") {
      var obj = name;
      Object.keys(obj).forEach(function(name) {
        var a = obj[name];
        Contract.link(name, a);
      });
      return;
    }

    Contract.links[name] = address;
  };

  Contract.contract_name   = Contract.prototype.contract_name   = "SmartRepository";
  Contract.generated_with  = Contract.prototype.generated_with  = "3.2.0";

  // Allow people to opt-in to breaking changes now.
  Contract.next_gen = false;

  var properties = {
    binary: function() {
      var binary = Contract.unlinked_binary;

      Object.keys(Contract.links).forEach(function(library_name) {
        var library_address = Contract.links[library_name];
        var regex = new RegExp("__" + library_name + "_*", "g");

        binary = binary.replace(regex, library_address.replace("0x", ""));
      });

      return binary;
    }
  };

  Object.keys(properties).forEach(function(key) {
    var getter = properties[key];

    var definition = {};
    definition.enumerable = true;
    definition.configurable = false;
    definition.get = getter;

    Object.defineProperty(Contract, key, definition);
    Object.defineProperty(Contract.prototype, key, definition);
  });

  bootstrap(Contract);

  if (typeof module != "undefined" && typeof module.exports != "undefined") {
    module.exports = Contract;
  } else {
    // There will only be one version of this contract in the browser,
    // and we can use that.
    window.SmartRepository = Contract;
  }
})();
