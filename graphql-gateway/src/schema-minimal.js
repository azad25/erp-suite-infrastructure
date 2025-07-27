const { gql } = require('apollo-server-express');

const typeDefs = gql`
  # Scalars
  scalar DateTime
  scalar JSON

  # Basic types
  type User {
    id: ID!
    email: String!
    name: String!
    createdAt: DateTime!
  }

  type Query {
    hello: String
    users: [User!]!
  }

  type Mutation {
    createUser(name: String!, email: String!): User
  }
`;

module.exports = typeDefs;