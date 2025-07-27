const { GraphQLScalarType } = require('graphql');
const { Kind } = require('graphql/language');

// Custom scalar types
const DateTimeType = new GraphQLScalarType({
  name: 'DateTime',
  description: 'Date custom scalar type',
  serialize(value) {
    return new Date(value).toISOString();
  },
  parseValue(value) {
    return new Date(value);
  },
  parseLiteral(ast) {
    if (ast.kind === Kind.STRING) {
      return new Date(ast.value);
    }
    return null;
  },
});

const JSONType = new GraphQLScalarType({
  name: 'JSON',
  description: 'JSON custom scalar type',
  serialize(value) {
    return value;
  },
  parseValue(value) {
    return value;
  },
  parseLiteral(ast) {
    if (ast.kind === Kind.STRING) {
      return JSON.parse(ast.value);
    }
    return null;
  },
});

const resolvers = {
  // Custom scalars
  DateTime: DateTimeType,
  JSON: JSONType,

  // Root Query resolvers
  Query: {
    hello: () => 'Hello from GraphQL Gateway!',
    users: () => [
      {
        id: '1',
        email: 'admin@example.com',
        name: 'Admin User',
        createdAt: new Date()
      }
    ]
  },

  // Root Mutation resolvers
  Mutation: {
    createUser: (parent, { name, email }) => ({
      id: Date.now().toString(),
      name,
      email,
      createdAt: new Date()
    })
  }
};

module.exports = resolvers;